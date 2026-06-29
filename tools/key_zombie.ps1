# Zombi sprite'ının checkerboard arka planını (RGB'ye gömülü, alpha yok) keyout eder.
# Kenarlardan flood-fill ile bağlı açık-nötr pikselleri şeffaf yapar; içteki gri tonlar korunur.
param(
    [string]$InPath = "assets\textures\enemies\zombie.png",
    [string]$OutPath = "assets\textures\enemies\zombie.png"
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $InPath))
$w = $src.Width
$h = $src.Height

# 32bpp ARGB kopyaya çiz
$bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($src, 0, 0, $w, $h)
$g.Dispose()
$src.Dispose()

$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stride = $data.Stride
$bytes = New-Object byte[] ($stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)

# Arka plan testi: parlak + nötr (checkerboard ~237 ve ~255)
function Test-Bg([int]$idx) {
    $b = $bytes[$idx]
    $gr = $bytes[$idx + 1]
    $r = $bytes[$idx + 2]
    $mn = [Math]::Min($r, [Math]::Min($gr, $b))
    if ($mn -lt 188) { return $false }
    if ([Math]::Abs($r - $gr) -gt 18) { return $false }
    if ([Math]::Abs($gr - $b) -gt 18) { return $false }
    if ([Math]::Abs($r - $b) -gt 18) { return $false }
    return $true
}

$visited = New-Object bool[] ($w * $h)
$stack = New-Object System.Collections.Generic.Stack[int]

# Kenar piksellerini başlangıç noktası olarak ekle
for ($x = 0; $x -lt $w; $x++) {
    $stack.Push($x)                     # üst satır
    $stack.Push((($h - 1) * $w) + $x)   # alt satır
}
for ($y = 0; $y -lt $h; $y++) {
    $stack.Push($y * $w)                # sol sütun
    $stack.Push(($y * $w) + ($w - 1))   # sağ sütun
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

    # Şeffaf yap
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

Write-Host "Cleared $cleared background pixels of $($w * $h). Saved -> $full"
