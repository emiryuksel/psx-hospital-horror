# Checkerboard (light) veya green-screen (green) arka planını keyout edip gerçek alpha üretir.
# Kenarlardan flood-fill ile bağlı arka plan piksellerini şeffaf yapar.
param(
    [string]$InPath,
    [string]$OutPath,
    [ValidateSet("light", "green")]
    [string]$Mode = "light"
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $InPath))
$w = $src.Width
$h = $src.Height

$bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.DrawImage($src, 0, 0, $w, $h)
$gfx.Dispose()
$src.Dispose()

$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stride = $data.Stride
$bytes = New-Object byte[] ($stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)

$isGreen = ($Mode -eq "green")

function Test-Bg([int]$idx) {
    $b = $bytes[$idx]
    $gr = $bytes[$idx + 1]
    $r = $bytes[$idx + 2]
    if ($script:isGreen) {
        # Yeşil baskın piksel
        if ($gr -lt 90) { return $false }
        if ($gr -le ($r + 28)) { return $false }
        if ($gr -le ($b + 28)) { return $false }
        return $true
    }
    else {
        $mn = [Math]::Min($r, [Math]::Min($gr, $b))
        if ($mn -lt 188) { return $false }
        if ([Math]::Abs($r - $gr) -gt 18) { return $false }
        if ([Math]::Abs($gr - $b) -gt 18) { return $false }
        if ([Math]::Abs($r - $b) -gt 18) { return $false }
        return $true
    }
}

$visited = New-Object bool[] ($w * $h)
$stack = New-Object System.Collections.Generic.Stack[int]

for ($x = 0; $x -lt $w; $x++) {
    $stack.Push($x)
    $stack.Push((($h - 1) * $w) + $x)
}
for ($y = 0; $y -lt $h; $y++) {
    $stack.Push($y * $w)
    $stack.Push(($y * $w) + ($w - 1))
}

$cleared = 0
while ($stack.Count -gt 0) {
    $p = $stack.Pop()
    if ($visited[$p]) { continue }
    $visited[$p] = $true
    $px = $p % $w
    $py = [int][Math]::Floor($p / $w)
    $idx = ($py * $stride) + ($px * 4)
    if (-not (Test-Bg $idx)) { continue }
    $bytes[$idx + 3] = 0
    $cleared++
    if ($px -gt 0) { $np = $p - 1; if (-not $visited[$np]) { $stack.Push($np) } }
    if ($px -lt $w - 1) { $np = $p + 1; if (-not $visited[$np]) { $stack.Push($np) } }
    if ($py -gt 0) { $np = $p - $w; if (-not $visited[$np]) { $stack.Push($np) } }
    if ($py -lt $h - 1) { $np = $p + $w; if (-not $visited[$np]) { $stack.Push($np) } }
}

[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
$bmp.UnlockBits($data)

$full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutPath))
$bmp.Save($full, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "Mode=$Mode Cleared $cleared / $($w * $h). Saved -> $full"
