# PSX hastane texture seti — temiz, yapisal, dusuk kontrast (nearest-neighbor friendly).
Add-Type -AssemblyName System.Drawing

$root = Join-Path $PSScriptRoot "..\assets\textures"
$hospital = Join-Path $root "hospital"
$props = Join-Path $root "props"
New-Item -ItemType Directory -Force -Path $hospital, $props | Out-Null

function Save-Bmp($bmp, $path) {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Clamp([int]$v) { [Math]::Max(0, [Math]::Min(255, $v)) }

# Deterministik hafif gurultu (-amp..amp arasi, dusuk frekans hissi)
$global:rand = New-Object Random 1337
function Grain([int]$amp) {
    return $global:rand.Next(-$amp, $amp + 1)
}

function Make-Wall {
    param([int]$Size = 128)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            # Karanlik hastane bojasi — koyu, sogukms gri, hafif dikey gradyan
            $vert = [int]([Math]::Sin($y * 0.025) * 5)
            $g = Grain 5
            $r = Clamp(46 + $vert + $g)
            $gn = Clamp(48 + $vert + $g)
            $b = Clamp(50 + $vert + $g)
            # bel hizasinda koyu sufurlu fayans hatti
            if ($y -eq 84 -or $y -eq 85) { $r -= 18; $gn -= 18; $b -= 16 }
            # alt taban supurgeligi — biraz daha koyu
            if ($y -gt 116) { $r -= 10; $gn -= 10; $b -= 9 }
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb((Clamp($r)), (Clamp($gn)), (Clamp($b))))
        }
    }
    Save-Bmp $bmp (Join-Path $hospital "wall.png")
}

function Make-Floor {
    param([int]$Size = 128)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $tile = 64
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $tx = $x % $tile
            $ty = $y % $tile
            $grout = ($tx -lt 2 -or $ty -lt 2)
            $g = Grain 6
            if ($grout) {
                $c = Clamp(26 + $g)
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c, $c, ($c + 2)))
            } else {
                $c = Clamp(52 + $g)
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(($c - 2), $c, ($c + 3)))
            }
        }
    }
    Save-Bmp $bmp (Join-Path $hospital "floor.png")
}

function Make-Ceiling {
    param([int]$Size = 128)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $tile = 32
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $tx = $x % $tile
            $ty = $y % $tile
            $line = ($tx -lt 1 -or $ty -lt 1)
            $g = Grain 4
            if ($line) {
                $c = Clamp(20 + $g)
            } else {
                $c = Clamp(44 + $g)
            }
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c, $c, (Clamp($c - 3))))
        }
    }
    Save-Bmp $bmp (Join-Path $hospital "ceiling.png")
}

function Make-Wood {
    param([int]$Size = 128)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $plank = 32
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $seam = (($y % $plank) -lt 2)
            $grain = [int]([Math]::Sin($x * 0.10 + ([Math]::Floor($y / $plank)) * 1.7) * 7)
            $g = Grain 4
            if ($seam) {
                $r = Clamp(26 + $g); $gn = Clamp(18 + $g); $b = Clamp(12 + $g)
            } else {
                $r = Clamp(56 + $grain + $g); $gn = Clamp(38 + [int]($grain * 0.6) + $g); $b = Clamp(24 + [int]($grain * 0.4) + $g)
            }
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($r, $gn, $b))
        }
    }
    Save-Bmp $bmp (Join-Path $hospital "wood.png")
}

function Make-Metal {
    param([int]$Size = 128)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $brush = [int]([Math]::Sin($x * 0.5) * 4)
            $g = Grain 3
            $c = Clamp(50 + $brush + $g)
            # panel dikis cizgileri
            if ($x % 42 -eq 0) { $c -= 22 }
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb((Clamp($c)), (Clamp($c + 2)), (Clamp($c + 7))))
        }
    }
    Save-Bmp $bmp (Join-Path $hospital "metal.png")
}

# Panelli kapi cizimi (tek goruntu kapi yuzeyine map'lenir)
function Draw-Door {
    param($bmp, [int]$Size, $frameCol, $panelCol, $recessCol)
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $g = Grain 3
            $frame = ($x -lt 10 -or $x -ge ($Size - 10) -or $y -lt 8 -or $y -ge ($Size - 8))
            $midRail = ($y -gt 60 -and $y -lt 72)
            $panelTop = ($x -gt 18 -and $x -lt ($Size - 18) -and $y -gt 14 -and $y -lt 58)
            $panelBot = ($x -gt 18 -and $x -lt ($Size - 18) -and $y -gt 74 -and $y -lt ($Size - 14))
            $recessEdgeT = ($panelTop -and ($x -lt 24 -or $x -gt ($Size - 24) -or $y -lt 20 -or $y -gt 52))
            $recessEdgeB = ($panelBot -and ($x -lt 24 -or $x -gt ($Size - 24) -or $y -lt 80 -or $y -gt ($Size - 20)))
            if ($frame -or $midRail) {
                $c = $frameCol
            } elseif ($recessEdgeT -or $recessEdgeB) {
                $c = $recessCol
            } elseif ($panelTop -or $panelBot) {
                $c = $panelCol
            } else {
                $c = $frameCol
            }
            $r = Clamp($c.R + $g); $gn = Clamp($c.G + $g); $b = Clamp($c.B + $g)
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($r, $gn, $b))
        }
    }
}

function Make-Door {
    param([int]$Size = 128)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    Draw-Door $bmp $Size ([System.Drawing.Color]::FromArgb(44, 34, 24)) ([System.Drawing.Color]::FromArgb(68, 52, 35)) ([System.Drawing.Color]::FromArgb(34, 26, 18))
    # kapi kolu (sonuk pirinc)
    for ($y = 60; $y -lt 70; $y++) { for ($x = 96; $x -lt 110; $x++) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(120, 112, 78)) } }
    Save-Bmp $bmp (Join-Path $hospital "door.png")
}

function Make-ExitDoor {
    param([int]$Size = 128)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    Draw-Door $bmp $Size ([System.Drawing.Color]::FromArgb(82, 18, 16)) ([System.Drawing.Color]::FromArgb(120, 26, 22)) ([System.Drawing.Color]::FromArgb(60, 12, 11))
    # ust EXIT levhasi (parlak yesil bar — karanlikta isaret feneri gibi cizici)
    for ($y = 16; $y -lt 30; $y++) {
        for ($x = 30; $x -lt ($Size - 30); $x++) {
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(36, 170, 78))
        }
    }
    # EXIT harfleri (kaba beyaz bloklar)
    $letters = @(34, 35, 36, 44, 45, 46, 54, 55, 56, 64, 65, 66, 74, 75, 76, 84, 85, 86)
    foreach ($lx in $letters) {
        for ($y = 19; $y -lt 27; $y++) { $bmp.SetPixel($lx, $y, [System.Drawing.Color]::FromArgb(225, 240, 225)) }
    }
    # itme barI (panik bar)
    for ($y = 78; $y -lt 86; $y++) { for ($x = 18; $x -lt ($Size - 18); $x++) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(140, 132, 116)) } }
    Save-Bmp $bmp (Join-Path $hospital "exit_door.png")
}

# ---- Proplar (64px) ----
function Make-Fuse {
    param([int]$Size = 64)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $inCap = ($x -gt 22 -and $x -lt 42 -and $y -gt 6 -and $y -lt 14)
            $inBody = ($x -gt 18 -and $x -lt 46 -and $y -ge 14 -and $y -lt 50)
            $inTip = ($x -gt 26 -and $x -lt 38 -and $y -ge 50 -and $y -lt 58)
            if ($inCap) { $c = [System.Drawing.Color]::FromArgb(185, 150, 60) }
            elseif ($inBody) {
                $band = [Math]::Floor(($y - 14) / 7) % 2
                if ($band -eq 0) { $c = [System.Drawing.Color]::FromArgb(225, 215, 180) }
                else { $c = [System.Drawing.Color]::FromArgb(200, 90, 55) }
            }
            elseif ($inTip) { $c = [System.Drawing.Color]::FromArgb(150, 150, 155) }
            else { $c = [System.Drawing.Color]::FromArgb(28, 28, 32) }
            $bmp.SetPixel($x, $y, $c)
        }
    }
    Save-Bmp $bmp (Join-Path $props "fuse.png")
}

function Make-Key {
    param([int]$Size = 64)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $c = [System.Drawing.Color]::FromArgb(28, 28, 32)
            $inHead = ((($x - 40) * ($x - 40) + ($y - 24) * ($y - 24)) -lt 90)
            $inHole = ((($x - 40) * ($x - 40) + ($y - 24) * ($y - 24)) -lt 18)
            $inShaft = ($x -gt 14 -and $x -lt 36 -and $y -gt 21 -and $y -lt 27)
            $inTeeth = (($x -gt 14 -and $x -lt 20 -and $y -ge 27 -and $y -lt 35) -or ($x -gt 22 -and $x -lt 28 -and $y -ge 27 -and $y -lt 37))
            if ($inHole) { $c = [System.Drawing.Color]::FromArgb(28, 28, 32) }
            elseif ($inHead -or $inShaft -or $inTeeth) {
                $g = Grain 12
                $c = [System.Drawing.Color]::FromArgb((Clamp(195 + $g)), (Clamp(160 + $g)), (Clamp(55 + $g)))
            }
            $bmp.SetPixel($x, $y, $c)
        }
    }
    Save-Bmp $bmp (Join-Path $props "key.png")
}

function Make-Herb {
    param([int]$Size = 64)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $l1 = ((($x - 32) * ($x - 32) + ($y - 26) * ($y - 26)) -lt 150)
            $l2 = ((($x - 22) * ($x - 22) + ($y - 38) * ($y - 38)) -lt 110)
            $l3 = ((($x - 42) * ($x - 42) + ($y - 38) * ($y - 38)) -lt 110)
            if ($l1 -or $l2 -or $l3) {
                $g = Grain 18
                $c = [System.Drawing.Color]::FromArgb((Clamp(28 + $g)), (Clamp(98 + $g)), (Clamp(34 + $g)))
            } else { $c = [System.Drawing.Color]::FromArgb(14, 18, 14) }
            $bmp.SetPixel($x, $y, $c)
        }
    }
    Save-Bmp $bmp (Join-Path $props "herb.png")
}

function Make-Ammo {
    param([int]$Size = 64)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $inBox = ($x -gt 10 -and $x -lt 54 -and $y -gt 20 -and $y -lt 46)
            $bullet = (($x -gt 18 -and $x -lt 24 -and $y -gt 24 -and $y -lt 42) -or ($x -gt 28 -and $x -lt 34 -and $y -gt 24 -and $y -lt 42) -or ($x -gt 38 -and $x -lt 44 -and $y -gt 24 -and $y -lt 42))
            if ($bullet) { $c = [System.Drawing.Color]::FromArgb(205, 178, 55) }
            elseif ($inBox) { $c = [System.Drawing.Color]::FromArgb(60, 62, 52) }
            else { $c = [System.Drawing.Color]::FromArgb(22, 22, 26) }
            $bmp.SetPixel($x, $y, $c)
        }
    }
    Save-Bmp $bmp (Join-Path $props "ammo.png")
}

function Make-Note {
    param([int]$Size = 64)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $paper = ($x -gt 8 -and $x -lt 56 -and $y -gt 6 -and $y -lt 58)
            if ($paper) {
                $line = (($y % 9) -eq 4 -and $x -gt 14 -and $x -lt 50)
                if ($line) { $c = [System.Drawing.Color]::FromArgb(96, 92, 80) }
                else { $g = Grain 5; $c = [System.Drawing.Color]::FromArgb((Clamp(150 + $g)), (Clamp(144 + $g)), (Clamp(124 + $g))) }
            } else { $c = [System.Drawing.Color]::FromArgb(14, 14, 16) }
            $bmp.SetPixel($x, $y, $c)
        }
    }
    Save-Bmp $bmp (Join-Path $props "note.png")
}

function Make-Debris {
    param([int]$Size = 64)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $g = Grain 14
            $c = Clamp(34 + $g)
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($c, (Clamp($c - 4)), (Clamp($c - 8))))
        }
    }
    Save-Bmp $bmp (Join-Path $props "debris.png")
}

function Make-Blood {
    param([int]$Size = 64)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    for ($y = 0; $y -lt $Size; $y++) {
        for ($x = 0; $x -lt $Size; $x++) {
            $dx = $x - 32; $dy = $y - 32
            $r2 = $dx * $dx + $dy * $dy
            $blob = ($r2 -lt 700) -or ($global:rand.Next(0, 100) -gt 88 -and $r2 -lt 1000)
            if ($blob) { $c = [System.Drawing.Color]::FromArgb(255, 74, 10, 9) }
            else { $c = [System.Drawing.Color]::FromArgb(0, 0, 0, 0) }
            $bmp.SetPixel($x, $y, $c)
        }
    }
    Save-Bmp $bmp (Join-Path $props "blood.png")
}

Make-Wall
Make-Floor
Make-Ceiling
Make-Wood
Make-Metal
Make-Door
Make-ExitDoor
Make-Fuse
Make-Key
Make-Herb
Make-Ammo
Make-Note
Make-Debris
Make-Blood

Write-Host "Generated PSX textures."
Get-ChildItem $hospital, $props -Filter "*.png" | Format-Table Name, Length
