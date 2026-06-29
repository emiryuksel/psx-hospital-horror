# PSX tarzi HUD ikonlari uretir — kalp (health), simsek/bolt (stamina), pil (flashlight).
# Dusuk cozunurluk, sinirli palet, sert pikseller — PSX survival horror HUD estetigi.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$hudDir = Join-Path $root "assets\textures\hud"
New-Item -ItemType Directory -Force -Path $hudDir | Out-Null

$C = [System.Drawing.Color]

function New-Bmp([int]$w, [int]$h) {
	return New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Fill-Transparent($bmp) {
	for ($y = 0; $y -lt $bmp.Height; $y++) {
		for ($x = 0; $x -lt $bmp.Width; $x++) {
			$bmp.SetPixel($x, $y, $C::FromArgb(0, 0, 0, 0))
		}
	}
}

function Rect($bmp, [int]$x0, [int]$y0, [int]$x1, [int]$y1, $col) {
	for ($y = $y0; $y -le $y1; $y++) {
		for ($x = $x0; $x -le $x1; $x++) {
			if ($x -ge 0 -and $y -ge 0 -and $x -lt $bmp.Width -and $y -lt $bmp.Height) {
				$bmp.SetPixel($x, $y, $col)
			}
		}
	}
}

function Px($bmp, [int]$x, [int]$y, $col) {
	if ($x -ge 0 -and $y -ge 0 -and $x -lt $bmp.Width -and $y -lt $bmp.Height) {
		$bmp.SetPixel($x, $y, $col)
	}
}

# ============================================================
#  KALP (HEART) — 16x16, tek frame. Renk parametreyle verilir.
#  state: "full" (dolu kirmizi), "half" (yarim), "empty" (bos kontur)
# ============================================================
function Build-Heart([string]$state) {
	$s = 16
	$bmp = New-Bmp $s $s
	Fill-Transparent $bmp

	$outline = $C::FromArgb(255, 28, 4, 4)
	$redHi = $C::FromArgb(255, 215, 70, 64)
	$red = $C::FromArgb(255, 158, 22, 22)
	$redDk = $C::FromArgb(255, 96, 8, 8)
	$emptyFill = $C::FromArgb(255, 46, 20, 20)

	# Klasik simetrik piksel kalp (16 genis, iki tepe + sivri dip)
	# Her satir: dolu x araliklari (govde)
	$rows = @(
		@(),                  # 0
		@(@(3,5),  @(10,12)), # 1  iki tepe
		@(@(2,6),  @(9,13)),  # 2
		@(@(2,13)),           # 3  birlesti
		@(@(2,13)),           # 4
		@(@(2,13)),           # 5
		@(@(2,13)),           # 6
		@(@(3,12)),           # 7
		@(@(4,11)),           # 8
		@(@(5,10)),           # 9
		@(@(6,9)),            # 10
		@(@(7,8)),            # 11  sivri dip
		@(),                  # 12
		@(),                  # 13
		@(),                  # 14
		@()                   # 15
	)

	for ($y = 0; $y -lt 16; $y++) {
		foreach ($seg in $rows[$y]) {
			$x0 = $seg[0]; $x1 = $seg[1]
			for ($x = $x0; $x -le $x1; $x++) {
				$col = $red
				if ($state -eq "empty") {
					$col = $emptyFill
				} elseif ($state -eq "half" -and $x -ge 8) {
					$col = $emptyFill   # sag yari bos
				}
				Px $bmp $x $y $col
			}
		}
	}

	if ($state -ne "empty") {
		# Sol-ust parlak vurgu (klasik kalp isigi)
		Rect $bmp 3 2 4 3 $redHi
		Px $bmp 3 4 $redHi
		Px $bmp 4 1 $redHi
		# Alt golge — dibe dogru koyulasma
		Px $bmp 7 11 $redDk
		Px $bmp 8 11 $redDk
		Rect $bmp 6 10 9 10 $redDk
		Px $bmp 5 9 $redDk
		Px $bmp 10 9 $redDk
	}

	# Kontur — maskenin dis hattini sar (yatay uclar + tepe/dip)
	for ($y = 0; $y -lt 16; $y++) {
		foreach ($seg in $rows[$y]) {
			Px $bmp ($seg[0] - 1) $y $outline
			Px $bmp ($seg[1] + 1) $y $outline
		}
	}
	# Tepe ustleri
	Px $bmp 4 0 $outline
	Px $bmp 11 0 $outline
	Rect $bmp 3 0 5 0 $outline
	Rect $bmp 10 0 12 0 $outline
	# Vadi (iki tepe arasi)
	Px $bmp 7 0 $outline
	Px $bmp 8 0 $outline
	Px $bmp 7 1 $outline
	Px $bmp 8 1 $outline
	# Dip alt kontur
	Px $bmp 7 12 $outline
	Px $bmp 8 12 $outline

	return $bmp
}

# ============================================================
#  BOLT (STAMINA) — 16x16. Simsek silueti.
#  state: "full" (sari-yesil enerji), "empty" (sonuk)
# ============================================================
function Build-Bolt([string]$state) {
	$s = 16
	$bmp = New-Bmp $s $s
	Fill-Transparent $bmp

	$outline = $C::FromArgb(255, 20, 24, 10)
	if ($state -eq "full") {
		$hi = $C::FromArgb(255, 220, 240, 130)
		$md = $C::FromArgb(255, 170, 200, 70)
		$dk = $C::FromArgb(255, 110, 140, 40)
	} else {
		$hi = $C::FromArgb(255, 60, 64, 50)
		$md = $C::FromArgb(255, 44, 48, 38)
		$dk = $C::FromArgb(255, 32, 34, 28)
	}

	# Simsek maskesi (16x16) — zikzak bolt
	$rows = @(
		@(),            # 0
		@(@(8,11)),     # 1
		@(@(7,11)),     # 2
		@(@(6,10)),     # 3
		@(@(5,10)),     # 4
		@(@(4,9)),      # 5
		@(@(4,12)),     # 6  ust genis taban
		@(@(4,11)),     # 7
		@(@(6,10)),     # 8  orta daralma
		@(@(5,9)),      # 9
		@(@(5,8)),      # 10
		@(@(4,8)),      # 11
		@(@(4,7)),      # 12
		@(@(4,6)),      # 13
		@(@(4,5)),      # 14
		@()             # 15
	)

	for ($y = 0; $y -lt 16; $y++) {
		foreach ($seg in $rows[$y]) {
			for ($x = $seg[0]; $x -le $seg[1]; $x++) {
				$col = $md
				# Sol kenar parlak, sag kenar koyu
				if ($x -eq $seg[0]) { $col = $hi }
				elseif ($x -eq $seg[1]) { $col = $dk }
				Px $bmp $x $y $col
			}
			# kontur
			Px $bmp ($seg[0] - 1) $y $outline
			Px $bmp ($seg[1] + 1) $y $outline
		}
	}

	return $bmp
}

# ============================================================
#  BATTERY (FLASHLIGHT) — 30x16. Govde + 3 dis (bar).
#  cells: 0..3 kac dis dolu gosterilecegi
# ============================================================
function Build-Battery([int]$cells) {
	$w = 30; $h = 16
	$bmp = New-Bmp $w $h
	Fill-Transparent $bmp

	$shell = $C::FromArgb(255, 60, 62, 58)
	$shellHi = $C::FromArgb(255, 110, 114, 106)
	$shellDk = $C::FromArgb(255, 30, 32, 30)
	$cap = $C::FromArgb(255, 150, 154, 146)
	$inner = $C::FromArgb(255, 16, 18, 16)
	$cellOn = $C::FromArgb(255, 120, 220, 120)
	$cellOnHi = $C::FromArgb(255, 170, 245, 160)
	$cellLow = $C::FromArgb(255, 230, 180, 60)   # tek dis kalinca uyari sarisi
	$cellCrit = $C::FromArgb(255, 220, 90, 50)   # kritik turuncu-kirmizi
	$cellOff = $C::FromArgb(255, 34, 40, 34)

	# Govde dis hat (1..25 genislik, 2..13 yukseklik)
	Rect $bmp 1 2 25 13 $shellDk
	Rect $bmp 2 3 24 12 $shell
	Rect $bmp 2 3 24 4 $shellHi          # ust parlak kenar
	Rect $bmp 3 5 23 11 $inner           # ic karanlik bosluk
	# Pozitif uc kapak (sag)
	Rect $bmp 26 5 28 10 $cap

	# 3 dis (bar) — ic boslukta esit araliklarla
	# Her dis: x araligi
	$barX = @(@(4,9), @(11,16), @(18,23))
	for ($i = 0; $i -lt 3; $i++) {
		$bx0 = $barX[$i][0]; $bx1 = $barX[$i][1]
		if ($i -lt $cells) {
			# Dolu dis — son dis kalinca renk uyari
			$fill = $cellOn
			$fillHi = $cellOnHi
			if ($cells -eq 1) { $fill = $cellCrit; $fillHi = $C::FromArgb(255, 245, 130, 90) }
			elseif ($cells -eq 2) { $fill = $cellLow; $fillHi = $C::FromArgb(255, 250, 210, 110) }
			Rect $bmp $bx0 6 $bx1 10 $fill
			Rect $bmp $bx0 6 $bx1 6 $fillHi
		} else {
			Rect $bmp $bx0 6 $bx1 10 $cellOff
		}
	}

	return $bmp
}

# ---- Uret & kaydet ----
function Save-Bmp($bmp, [string]$name) {
	$bmp.Save((Join-Path $hudDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
}

Save-Bmp (Build-Heart "full")  "heart_full.png"
Save-Bmp (Build-Heart "half")  "heart_half.png"
Save-Bmp (Build-Heart "empty") "heart_empty.png"

Save-Bmp (Build-Bolt "full")  "bolt_full.png"
Save-Bmp (Build-Bolt "empty") "bolt_empty.png"

Save-Bmp (Build-Battery 3) "battery_3.png"
Save-Bmp (Build-Battery 2) "battery_2.png"
Save-Bmp (Build-Battery 1) "battery_1.png"
Save-Bmp (Build-Battery 0) "battery_0.png"

Write-Host "HUD ikonlari uretildi:"
Write-Host "  $hudDir\heart_full.png / heart_half.png / heart_empty.png"
Write-Host "  $hudDir\bolt_full.png / bolt_empty.png"
Write-Host "  $hudDir\battery_3.png / battery_2.png / battery_1.png / battery_0.png"
