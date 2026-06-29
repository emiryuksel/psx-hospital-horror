# PSX tarzi silah viewmodel + muzzle flash + kan + hasar vinyeti uretir.
# Dusuk cozunurluk, sinirli palet, dithering hissi — el cizimi PSX sprite estetigi.
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$weaponsDir = Join-Path $root "assets\textures\weapons"
$fxDir = Join-Path $root "assets\textures\fx"
New-Item -ItemType Directory -Force -Path $weaponsDir | Out-Null
New-Item -ItemType Directory -Force -Path $fxDir | Out-Null

function New-Bmp([int]$w, [int]$h) {
	$bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	return $bmp
}

function Fill-Transparent($bmp) {
	for ($y = 0; $y -lt $bmp.Height; $y++) {
		for ($x = 0; $x -lt $bmp.Width; $x++) {
			$bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
		}
	}
}

# Tek piksel (sinir kontrollu)
function Px($bmp, [int]$x, [int]$y, $col) {
	if ($x -ge 0 -and $y -ge 0 -and $x -lt $bmp.Width -and $y -lt $bmp.Height) {
		$bmp.SetPixel($x, $y, $col)
	}
}

# Dikdortgen doldur (PSX flat shade)
function Rect($bmp, [int]$x0, [int]$y0, [int]$x1, [int]$y1, $col) {
	for ($y = $y0; $y -le $y1; $y++) {
		for ($x = $x0; $x -le $x1; $x++) {
			if ($x -ge 0 -and $y -ge 0 -and $x -lt $bmp.Width -and $y -lt $bmp.Height) {
				$bmp.SetPixel($x, $y, $col)
			}
		}
	}
}

# Egimli dolgu — y0..y1 araliginda ust genislik (x0u..x1u) alt genislige (x0d..x1d) gecer.
# Perspektif egimi icin kullanilir.
function FillSlope($bmp, [int]$y0, [int]$y1, [int]$x0u, [int]$x1u, [int]$x0d, [int]$x1d, $col) {
	$span = [Math]::Max(1, $y1 - $y0)
	for ($y = $y0; $y -le $y1; $y++) {
		$t = ($y - $y0) / [double]$span
		$xa = [int]([Math]::Round($x0u + ($x0d - $x0u) * $t))
		$xb = [int]([Math]::Round($x1u + ($x1d - $x1u) * $t))
		for ($x = $xa; $x -le $xb; $x++) {
			if ($x -ge 0 -and $y -ge 0 -and $x -lt $bmp.Width -and $y -lt $bmp.Height) {
				$bmp.SetPixel($x, $y, $col)
			}
		}
	}
}

$C = [System.Drawing.Color]

# ---- Pistol IDLE viewmodel (180x130) — Half-Life 1 (Glock/9mmAR) perspektif ----
# Foreshortening: slide ARKASI (sag) izleyiciye yakin+kalin, namlu UCU (sol) uzak+ince.
# Namlu ekran merkezine dogru sola+hafif yukari bakar. Kabza sag-alttan ~70 derece iner.
function Build-Pistol([bool]$firing) {
	$w = 180; $h = 130
	$bmp = New-Bmp $w $h
	Fill-Transparent $bmp

	# Metal palet (mavi-gri, sinirli — PSX)
	$steelHi = $C::FromArgb(255, 122, 128, 144)
	$steel = $C::FromArgb(255, 82, 88, 102)
	$steelMd = $C::FromArgb(255, 56, 61, 72)
	$steelDk = $C::FromArgb(255, 34, 37, 46)
	$steelBk = $C::FromArgb(255, 18, 20, 26)
	# Deri/el paleti
	$skinHi = $C::FromArgb(255, 154, 122, 100)
	$skin = $C::FromArgb(255, 128, 99, 80)
	$skinMd = $C::FromArgb(255, 102, 77, 62)
	$skinDk = $C::FromArgb(255, 74, 54, 43)
	# Kabza paleti (koyu polimer)
	$gripHi = $C::FromArgb(255, 60, 52, 48)
	$grip = $C::FromArgb(255, 42, 36, 33)
	$gripDk = $C::FromArgb(255, 24, 20, 18)

	$rec = if ($firing) { 7 } else { 0 }  # ates: slide geri (saga) kayar

	# ===== SLIDE / GOVDE — hafif acili, dolgun tabanca govdesi (cok ucgen olmasin) =====
	# Namlu ucu (sol) y~40, slide arkasi (sag) y~50 — yumusak egim.
	# Kalinlik solda 18px, sagda 26px — hafif foreshortening, dolgun govde.
	$xL = 18; $xR = 150 + $rec
	for ($x = $xL; $x -le $xR; $x++) {
		$t = ($x - $xL) / [double]($xR - $xL)   # 0=sol/namlu .. 1=sag/arka
		# Ust kenar dogrusal iner: sol y=38 -> sag y=48 (hafif egim)
		$topY = [int]([Math]::Round(38 + $t * 10))
		# Kalinlik dogrusal artar: 18 -> 26 (dolgun, az foreshortening)
		$thick = [int]([Math]::Round(18 + $t * 8))
		$botY = $topY + $thick
		for ($y = $topY; $y -le $botY; $y++) {
			$bmp.SetPixel($x, $y, $steel)
		}
		# Ust parlak kenar
		$bmp.SetPixel($x, $topY, $steelHi)
		if (($topY + 1) -le $botY) { $bmp.SetPixel($x, $topY + 1, $steelHi) }
		# Alt golge
		$bmp.SetPixel($x, $botY, $steelBk)
		if (($botY - 1) -ge $topY) { $bmp.SetPixel($x, $botY - 1, $steelDk) }
	}

	# Namlu agzi (sol uc)
	Rect $bmp 10 40 20 56 $steelDk
	Rect $bmp 6 44 14 52 $steelBk
	Rect $bmp 7 46 12 50 $C::FromArgb(255, 6, 6, 8)   # namlu deligi

	# Slide tirtiklari (sag arka)
	for ($i = 0; $i -lt 6; $i++) {
		$sx = 120 + $rec + $i * 5
		Rect $bmp $sx 52 ($sx + 2) 72 $steelMd
	}
	# On nisangah (sol uc ust)
	Rect $bmp 30 34 35 39 $steel
	# Arka nisangah (sag ust)
	Rect $bmp (140 + $rec) 44 (150 + $rec) 50 $steel

	# ===== Cerceve / tetik bolgesi (govde altinda, sag-orta) =====
	Rect $bmp 100 76 148 90 $steelMd
	Rect $bmp 100 76 148 79 $steel
	# Tetik korumasi (halka)
	Rect $bmp 108 82 132 106 $steelDk
	Rect $bmp 112 86 128 102 ($C::FromArgb(0, 0, 0, 0))   # ic bosluk
	Rect $bmp 112 86 128 90 $steelMd                        # ic ust kenar
	# Tetik
	Rect $bmp 118 90 123 100 $steelBk

	# ===== Kabza — sag-alttan dik aci ile iner (yakin, buyuk) =====
	FillSlope $bmp 80 128 130 158 148 178 $gripDk
	FillSlope $bmp 82 124 133 154 150 174 $grip
	FillSlope $bmp 84 116 135 150 148 164 $gripHi
	# Kabza dokusu cizgileri
	for ($i = 0; $i -lt 6; $i++) {
		$gy = 90 + $i * 6
		Rect $bmp 136 $gy 158 ($gy + 1) $gripDk
	}

	# ===== Kavrayan el (alt-sag, kabzayi sarar) — buyuk ve baskin =====
	Rect $bmp 124 98 180 130 $skinDk
	Rect $bmp 126 100 178 128 $skinMd
	Rect $bmp 128 102 172 122 $skin
	# Bas parmak (kabzanin sol-ust)
	Rect $bmp 116 90 140 112 $skin
	Rect $bmp 116 90 136 96 $skinHi
	# Parmaklar tetik korumasinin onunde (yatay bantlar)
	Rect $bmp 104 96 138 118 $skin
	Rect $bmp 104 96 138 100 $skinHi
	Rect $bmp 106 104 138 105 $skinDk
	Rect $bmp 108 110 138 111 $skinDk
	# Isaret parmagi tetikte
	Rect $bmp 114 86 128 98 $skin

	if ($firing) {
		# Ates: slide ust kenari parlak vurgu (sol yariy)
		for ($x = $xL; $x -le ($xL + 80); $x++) {
			$t = ($x - $xL) / [double]($xR - $xL)
			$topY = [int]([Math]::Round(38 + $t * 10))
			$bmp.SetPixel($x, $topY, $C::FromArgb(255, 162, 168, 184))
			$bmp.SetPixel($x, $topY + 1, $C::FromArgb(255, 140, 146, 162))
		}
	}

	return $bmp
}

$idle = Build-Pistol $false
$idle.Save((Join-Path $weaponsDir "pistol_idle.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$idle.Dispose()

$fire = Build-Pistol $true
$fire.Save((Join-Path $weaponsDir "pistol_fire.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$fire.Dispose()

# ---- Knife IDLE/STAB viewmodel (180x130) — sag-altta elde tutulan bicak ----
# Pistol ile ayni tuval; bicak sag-alttan yukari-sola dogru tutulur.
function Build-Knife([bool]$stabbing) {
	$w = 180; $h = 130
	$bmp = New-Bmp $w $h
	Fill-Transparent $bmp

	$bladeHi = $C::FromArgb(255, 196, 202, 214)
	$blade = $C::FromArgb(255, 150, 156, 170)
	$bladeMd = $C::FromArgb(255, 104, 110, 124)
	$bladeDk = $C::FromArgb(255, 60, 64, 76)
	$edge = $C::FromArgb(255, 224, 228, 238)
	$guard = $C::FromArgb(255, 64, 60, 54)
	$handleHi = $C::FromArgb(255, 86, 60, 42)
	$handle = $C::FromArgb(255, 60, 40, 28)
	$handleDk = $C::FromArgb(255, 38, 24, 16)
	$skinHi = $C::FromArgb(255, 154, 122, 100)
	$skin = $C::FromArgb(255, 128, 99, 80)
	$skinDk = $C::FromArgb(255, 92, 68, 54)

	$adv = if ($stabbing) { -24 } else { 0 }   # sapla: ileri (sol-yukari) guclu hamle

	# ===== BICAK SIRTI: sag-alt kabzadan sol-yukari uca dogru diagonal =====
	# Diagonal cizgi: kabza (sag-alt ~x120,y100) -> uc (sol-yukari ~x40,y28)
	$x0 = 120 + $adv; $y0 = 100 + $adv
	$x1 = 40 + $adv;  $y1 = 28 + $adv
	$steps = 90
	for ($i = 0; $i -le $steps; $i++) {
		$t = $i / [double]$steps
		$bx = [int]([Math]::Round($x0 + ($x1 - $x0) * $t))
		$by = [int]([Math]::Round($y0 + ($y1 - $y0) * $t))
		# Genislik uca dogru incelir (kabzada 16, ucta 2)
		$wdt = [int]([Math]::Round(16 - $t * 14))
		for ($k = 0; $k -le $wdt; $k++) {
			# Sirt yonu (sag-asagi normal) boyunca dolgu
			$px = $bx + $k
			$py = $by + $k
			if ($k -eq 0) {
				Px $bmp $px $py $edge          # keskin agiz (sol-ust kenar)
			} elseif ($k -lt $wdt - 1) {
				$col = if ($k -lt $wdt * 0.4) { $bladeHi } else { $blade }
				Px $bmp $px $py $col
			} else {
				Px $bmp $px $py $bladeDk        # sirt golgesi
			}
		}
	}

	# ===== GUARD (kabza ile bicak arasi) =====
	$gx = 116 + $adv; $gy = 96 + $adv
	Rect $bmp ($gx - 6) ($gy - 6) ($gx + 10) ($gy + 10) $guard

	# ===== KABZA: sag-alta dogru =====
	FillSlope $bmp ($gy + 4) ($gy + 44) ($gx + 2) ($gx + 16) ($gx + 14) ($gx + 30) $handleDk
	FillSlope $bmp ($gy + 4) ($gy + 40) ($gx + 4) ($gx + 14) ($gx + 16) ($gx + 26) $handle
	FillSlope $bmp ($gy + 4) ($gy + 30) ($gx + 5) ($gx + 12) ($gx + 14) ($gx + 21) $handleHi

	# ===== KAVRAYAN EL (sag-alt, kabzayi sarar) =====
	Rect $bmp ($gx + 2) ($gy + 18) ($gx + 50) ($gy + 46) $skinDk
	Rect $bmp ($gx + 4) ($gy + 20) ($gx + 46) ($gy + 42) $skin
	Rect $bmp ($gx + 4) ($gy + 20) ($gx + 46) ($gy + 24) $skinHi
	# Parmaklar (kabza onunde yatay bantlar)
	for ($f = 0; $f -lt 4; $f++) {
		$fy = $gy + 22 + $f * 5
		Rect $bmp ($gx - 4) $fy ($gx + 18) ($fy + 3) $skin
		Px $bmp ($gx - 4) $fy $skinDk
	}

	if ($stabbing) {
		# SAPLA: agiz boyunca parlak flash + motion slash cizigileri + kirmizi splash
		$slashWhite = $C::FromArgb(255, 252, 250, 255)
		$slashHi = $C::FromArgb(255, 240, 244, 252)
		$slashMd = $C::FromArgb(200, 210, 215, 240)
		$slashRed = $C::FromArgb(180, 200, 60, 50)

		# Parlak agiz flash (kalin cizgi)
		for ($i = 0; $i -le $steps; $i++) {
			$t = $i / [double]$steps
			$bx = [int]([Math]::Round($x0 + ($x1 - $x0) * $t))
			$by = [int]([Math]::Round($y0 + ($y1 - $y0) * $t))
			Px $bmp $bx $by $slashWhite
			Px $bmp ($bx - 1) ($by - 1) $slashHi
			Px $bmp ($bx + 1) ($by + 1) $slashMd
		}

		# Uc noktasindan yayilan motion streak'ler (4 cizgi, farkli acilarda)
		$tipX = $x1; $tipY = $y1
		$streakDirs = @(
			@(-1, -2),
			@(-2, -1),
			@(0, -2),
			@(-2, 0)
		)
		foreach ($dir in $streakDirs) {
			for ($s = 1; $s -le 14; $s++) {
				$sx = $tipX + $dir[0] * $s
				$sy = $tipY + $dir[1] * $s
				$a = [int](255 - $s * 16)
				if ($a -lt 40) { $a = 40 }
				$streakCol = $C::FromArgb($a, 240, 242, 255)
				Px $bmp $sx $sy $streakCol
			}
		}

		# Uc civari kirmizimsi splash parcaciklari (4-6 piksel daginik)
		$splashPts = @(
			@(($tipX - 4), ($tipY - 5)),
			@(($tipX - 7), ($tipY - 2)),
			@(($tipX - 2), ($tipY - 8)),
			@(($tipX - 9), ($tipY - 4)),
			@(($tipX - 5), ($tipY - 9)),
			@(($tipX - 11), ($tipY - 1))
		)
		foreach ($pt in $splashPts) {
			Px $bmp $pt[0] $pt[1] $slashRed
			Px $bmp ($pt[0]+1) $pt[1] $slashRed
		}
	}

	return $bmp
}

$kIdle = Build-Knife $false
$kIdle.Save((Join-Path $weaponsDir "knife_idle.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$kIdle.Dispose()

$kStab = Build-Knife $true
$kStab.Save((Join-Path $weaponsDir "knife_fire.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$kStab.Dispose()

# ---- Muzzle flash (48x48) — sarimsi-beyaz yildiz ----
$mw = 48; $mh = 48
$mbmp = New-Bmp $mw $mh
Fill-Transparent $mbmp
$cx = 24; $cy = 24
$flashCore = $C::FromArgb(255, 255, 248, 220)
$flashMid = $C::FromArgb(255, 255, 210, 90)
$flashOut = $C::FromArgb(200, 230, 150, 40)
# Cekirdek
Rect $mbmp ($cx-6) ($cy-6) ($cx+6) ($cy+6) $flashCore
# Isinlar (yatay/dikey)
Rect $mbmp ($cx-22) ($cy-2) ($cx+22) ($cy+2) $flashMid
Rect $mbmp ($cx-2) ($cy-22) ($cx+2) ($cy+22) $flashMid
# Capraz nokta isaretleri
Rect $mbmp ($cx-14) ($cy-14) ($cx-8) ($cy-8) $flashOut
Rect $mbmp ($cx+8) ($cy+8) ($cx+14) ($cy+14) $flashOut
Rect $mbmp ($cx+8) ($cy-14) ($cx+14) ($cy-8) $flashOut
Rect $mbmp ($cx-14) ($cy+8) ($cx-8) ($cy+14) $flashOut
$mbmp.Save((Join-Path $fxDir "muzzle_flash.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$mbmp.Dispose()

# ---- Blood splat (32x32) — koyu kirmizi duzensiz sicrama ----
$bw = 32; $bh = 32
$bbmp = New-Bmp $bw $bh
Fill-Transparent $bbmp
$rng = New-Object System.Random(1337)
$bloodDk = $C::FromArgb(255, 70, 8, 8)
$bloodMd = $C::FromArgb(255, 120, 14, 12)
$bloodHi = $C::FromArgb(255, 160, 24, 20)
# Merkez kume
$bcx = 16; $bcy = 16
Rect $bbmp ($bcx-7) ($bcy-7) ($bcx+7) ($bcy+7) $bloodMd
Rect $bbmp ($bcx-5) ($bcy-5) ($bcx+5) ($bcy+5) $bloodHi
Rect $bbmp ($bcx-3) ($bcy-3) ($bcx+3) ($bcy+3) $bloodDk
# Rastgele damlacIklar
for ($i = 0; $i -lt 26; $i++) {
	$px = $rng.Next(2, 30)
	$py = $rng.Next(2, 30)
	$sz = $rng.Next(1, 3)
	$col = if (($i % 2) -eq 0) { $bloodMd } else { $bloodDk }
	Rect $bbmp $px $py ($px+$sz) ($py+$sz) $col
}
$bbmp.Save((Join-Path $fxDir "blood_splat.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$bbmp.Dispose()

# ---- Damage vignette (128x96) — kenarlardan ice kirmizi solma ----
$vw = 128; $vh = 96
$vbmp = New-Bmp $vw $vh
for ($y = 0; $y -lt $vh; $y++) {
	for ($x = 0; $x -lt $vw; $x++) {
		# Merkeze normalize uzaklik
		$nx = ($x - $vw / 2.0) / ($vw / 2.0)
		$ny = ($y - $vh / 2.0) / ($vh / 2.0)
		$d = [Math]::Sqrt($nx * $nx + $ny * $ny)
		$a = [int](([Math]::Max(0.0, $d - 0.45) / 0.55) * 255)
		if ($a -lt 0) { $a = 0 }
		if ($a -gt 255) { $a = 255 }
		$vbmp.SetPixel($x, $y, $C::FromArgb($a, 150, 0, 0))
	}
}
$vbmp.Save((Join-Path $fxDir "damage_vignette.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$vbmp.Dispose()

# ---- Pickup pistol (64x40) — USTTEN bakis silah silueti, SEFFAF zemin ----
# Masaya yatay quad olarak konur; sadece silah gorunur (zemin seffaf).
$propsDir = Join-Path $root "assets\textures\props"
New-Item -ItemType Directory -Force -Path $propsDir | Out-Null
$pw = 64; $ph = 40
$pbmp = New-Bmp $pw $ph
Fill-Transparent $pbmp
$pSteelHi = $C::FromArgb(255, 130, 136, 152)
$pSteel = $C::FromArgb(255, 90, 96, 110)
$pSteelMd = $C::FromArgb(255, 60, 66, 78)
$pSteelDk = $C::FromArgb(255, 34, 38, 48)
$pSteelBk = $C::FromArgb(255, 18, 20, 26)
$pGrip = $C::FromArgb(255, 46, 38, 34)
$pGripHi = $C::FromArgb(255, 66, 55, 48)
$pGripDk = $C::FromArgb(255, 26, 21, 18)

# Slide / govde (yatay uzun blok, sol = namlu) — ustten gorunum
Rect $pbmp 4 10 52 22 $pSteelDk
Rect $pbmp 5 11 51 21 $pSteel
Rect $pbmp 5 11 51 13 $pSteelHi       # ust parlak kenar
Rect $pbmp 5 20 51 21 $pSteelBk       # alt golge
# Namlu agzi (sol uc)
Rect $pbmp 1 13 5 19 $pSteelMd
Rect $pbmp 0 15 3 17 ($C::FromArgb(255, 6, 6, 8))   # namlu deligi
# Slide tirtiklari (sag)
for ($i = 0; $i -lt 6; $i++) {
	$sx = 40 + $i * 2
	Rect $pbmp $sx 12 $sx 20 $pSteelMd
}
# On nisangah
Rect $pbmp 8 9 11 10 $pSteelHi
# Arka nisangah
Rect $pbmp 48 9 51 10 $pSteelHi

# Tetik korumasi (govde altinda)
Rect $pbmp 32 22 44 32 $pSteelDk
Rect $pbmp 35 24 41 30 ($C::FromArgb(0, 0, 0, 0))    # ic bosluk (seffaf)
Rect $pbmp 35 24 41 25 $pSteelMd                       # ic ust
# Tetik
Rect $pbmp 37 25 39 29 $pSteelBk

# Kabza (asagi-saga egimli, dokulu)
Rect $pbmp 40 21 56 38 $pGripDk
Rect $pbmp 42 21 54 36 $pGrip
Rect $pbmp 42 21 54 23 $pGripHi
# Kabza tirtik dokusu
for ($i = 0; $i -lt 4; $i++) {
	$gy = 26 + $i * 3
	Rect $pbmp 43 $gy 53 $gy $pGripDk
}
$pbmp.Save((Join-Path $propsDir "pistol.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$pbmp.Dispose()

# ---- KNIFE PICKUP texture (64x40) — ustten bicak silueti, SEFFAF ----
$kw = 64; $kh = 40
$kbmp = New-Bmp $kw $kh
Fill-Transparent $kbmp
$kBladeHi = $C::FromArgb(255, 196, 202, 214)
$kBlade   = $C::FromArgb(255, 150, 156, 170)
$kBladeDk = $C::FromArgb(255, 96, 101, 114)
$kEdge    = $C::FromArgb(255, 224, 228, 238)
$kGuard   = $C::FromArgb(255, 70, 66, 60)
$kHandleHi= $C::FromArgb(255, 92, 64, 44)
$kHandle  = $C::FromArgb(255, 62, 42, 28)
$kHandleDk= $C::FromArgb(255, 40, 26, 16)

# Bicak yatay: sol uc (sivri) -> sag kabza. Orta y=20.
# Agiz (blade): sol 3..38, ust kenar keskinlesir
for ($x = 3; $x -le 38; $x++) {
	$t = ($x - 3) / 35.0
	# Ucta dar, kabzaya dogru genisler (2 -> 9 px yari-genislik)
	$hw = [int]([Math]::Round(1 + $t * 8))
	for ($dy = -$hw; $dy -le $hw; $dy++) {
		$y = 20 + $dy
		if ($dy -eq -$hw) {
			Px $kbmp $x $y $kEdge          # keskin agiz (ust)
		} elseif ($dy -ge ($hw - 1)) {
			Px $kbmp $x $y $kBladeDk        # sirt (alt)
		} elseif ($dy -lt 0) {
			Px $kbmp $x $y $kBladeHi
		} else {
			Px $kbmp $x $y $kBlade
		}
	}
}
# Sivri uc vurgusu
Px $kbmp 2 20 $kEdge
Px $kbmp 1 20 $kBladeHi

# Guard (40..43)
Rect $kbmp 39 12 43 28 $kGuard

# Kabza (44..60)
Rect $kbmp 44 15 60 25 $kHandleDk
Rect $kbmp 45 16 59 24 $kHandle
Rect $kbmp 45 16 59 17 $kHandleHi
# Perçinler
Px $kbmp 49 20 $kHandleDk
Px $kbmp 54 20 $kHandleDk
# Kabza ucu yuvarlatma
Px $kbmp 60 16 ($C::FromArgb(0,0,0,0))
Px $kbmp 60 24 ($C::FromArgb(0,0,0,0))

$kbmp.Save((Join-Path $propsDir "knife.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$kbmp.Dispose()


# ---- "TAKE PISTOL" pixel yazi (96x16) — pickup uzerinde billboard etiket, SEFFAF ----
$tw = 96; $th = 16
$tbmp = New-Bmp $tw $th
Fill-Transparent $tbmp
$txtCol = $C::FromArgb(255, 235, 230, 200)
$txtSh = $C::FromArgb(255, 30, 26, 18)

# 3x5 piksel font — sadece gerekli harfler (TAKE PISTOL)
$font = @{
	'T' = @("111","010","010","010","010")
	'A' = @("010","101","111","101","101")
	'K' = @("101","110","100","110","101")
	'E' = @("111","100","110","100","111")
	'P' = @("110","101","110","100","100")
	'I' = @("111","010","010","010","111")
	'S' = @("011","100","010","001","110")
	'O' = @("010","101","101","101","010")
	'L' = @("100","100","100","100","111")
	' ' = @("000","000","000","000","000")
}

function Draw-Text($bmp, [string]$text, [int]$ox, [int]$oy, $col, $sh, $fontTbl) {
	$cx = $ox
	foreach ($ch in $text.ToCharArray()) {
		$glyph = $fontTbl[[string]$ch]
		if ($null -ne $glyph) {
			for ($row = 0; $row -lt 5; $row++) {
				$line = $glyph[$row]
				for ($colIdx = 0; $colIdx -lt 3; $colIdx++) {
					if ($line[$colIdx] -eq '1') {
						# Golge (sag-alt)
						if ($null -ne $sh) {
							$bmp.SetPixel(($cx + $colIdx + 1), ($oy + $row + 1), $sh)
						}
						$bmp.SetPixel(($cx + $colIdx), ($oy + $row), $col)
					}
				}
			}
		}
		$cx += 4   # harf genisligi 3 + 1 bosluk
	}
}

Draw-Text $tbmp "TAKE PISTOL" 4 5 $txtCol $txtSh $font
$tbmp.Save((Join-Path $propsDir "label_take_pistol.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$tbmp.Dispose()

Write-Host "Silah / FX texture'lari uretildi:"
Write-Host "  $weaponsDir\pistol_idle.png"
Write-Host "  $weaponsDir\pistol_fire.png"
Write-Host "  $weaponsDir\knife_idle.png"
Write-Host "  $weaponsDir\knife_fire.png"
Write-Host "  $fxDir\muzzle_flash.png"
Write-Host "  $fxDir\blood_splat.png"
Write-Host "  $fxDir\damage_vignette.png"
Write-Host "  $propsDir\pistol.png"
Write-Host "  $propsDir\knife.png"
