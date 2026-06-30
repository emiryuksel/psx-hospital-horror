# PSX tarzi prosedurel ses efekti (SFX) ureticisi — 16-bit mono WAV, 22050 Hz.
# Cikti: assets/audio/sfx/*.wav ve assets/audio/ambient/*.wav

$ErrorActionPreference = "Stop"
$SR = 22050
$rng = New-Object System.Random(1337)

$sfxDir = "assets\audio\sfx"
$ambDir = "assets\audio\ambient"
New-Item -ItemType Directory -Force -Path $sfxDir | Out-Null
New-Item -ItemType Directory -Force -Path $ambDir | Out-Null

function New-Buf([double]$seconds) {
    return New-Object 'double[]' ([int]($seconds * $SR))
}

function Add-Tone([double[]]$buf, [double]$f0, [double]$f1, [double]$start, [double]$dur, [double]$amp, [double]$atk, [double]$rel, [string]$wave = "sine") {
    $s = [int]($start * $SR)
    $len = [int]($dur * $SR)
    if ($len -le 0) { return }
    $end = $s + $len
    if ($end -gt $buf.Length) { $end = $buf.Length }
    for ($i = $s; $i -lt $end; $i++) {
        $t = ($i - $s) / [double]$SR
        $frac = ($i - $s) / [double]$len
        $f = $f0 + ($f1 - $f0) * $frac
        $ph = 2.0 * [math]::PI * $f * $t
        $val = 0.0
        if ($wave -eq "saw") {
            $val = 2.0 * (($f * $t) % 1.0) - 1.0
        }
        elseif ($wave -eq "square") {
            if ([math]::Sin($ph) -ge 0) { $val = 1.0 } else { $val = -1.0 }
        }
        else {
            $val = [math]::Sin($ph)
        }
        $env = 1.0
        if ($atk -gt 0 -and $t -lt $atk) { $env = $t / $atk }
        $tr = $dur - $t
        if ($rel -gt 0 -and $tr -lt $rel) { $env *= [math]::Max(0.0, $tr / $rel) }
        $buf[$i] += $val * $amp * $env
    }
}

function Add-Noise([double[]]$buf, [double]$start, [double]$dur, [double]$amp, [double]$lp, [double]$decayPow = 1.5) {
    $s = [int]($start * $SR)
    $len = [int]($dur * $SR)
    if ($len -le 0) { return }
    $end = $s + $len
    if ($end -gt $buf.Length) { $end = $buf.Length }
    $prev = 0.0
    for ($i = $s; $i -lt $end; $i++) {
        $w = ($rng.NextDouble() * 2.0 - 1.0)
        $prev = $prev + $lp * ($w - $prev)
        $frac = ($i - $s) / [double]$len
        $env = [math]::Pow([math]::Max(0.0, 1.0 - $frac), $decayPow)
        $buf[$i] += $prev * $amp * $env
    }
}

function Add-Growl([double[]]$buf, [double]$start, [double]$dur, [double]$amp, [double]$am1, [double]$am2, [double]$lp) {
    $s = [int]($start * $SR)
    $len = [int]($dur * $SR)
    $end = $s + $len
    if ($end -gt $buf.Length) { $end = $buf.Length }
    $prev = 0.0
    for ($i = $s; $i -lt $end; $i++) {
        $t = ($i - $s) / [double]$SR
        $w = ($rng.NextDouble() * 2.0 - 1.0)
        $prev = $prev + $lp * ($w - $prev)
        $mod = 0.6 + 0.4 * [math]::Sin(2.0 * [math]::PI * $am1 * $t)
        $mod *= 0.7 + 0.3 * [math]::Sin(2.0 * [math]::PI * $am2 * $t + 1.3)
        $frac = $t / $dur
        $env = [math]::Sin([math]::PI * [math]::Min(1.0, $frac))
        $buf[$i] += $prev * $amp * $mod * $env
    }
}

function Apply-PsxCrush([double[]]$buf, [double]$gain = 1.12) {
    for ($i = 0; $i -lt $buf.Length; $i++) {
        $v = $buf[$i] * $gain
        $v = [math]::Round($v * 28.0) / 28.0
        if ($v -gt 0.82) { $v = 0.82 + ($v - 0.82) * 0.25 }
        if ($v -lt -0.82) { $v = -0.82 + ($v + 0.82) * 0.25 }
        $buf[$i] = $v
    }
}


function Apply-SoftEcho([double[]]$buf) {
    $dry = New-Object 'double[]' $buf.Length
    [array]::Copy($buf, $dry, $buf.Length)
    $delays = @(0.044, 0.082, 0.128)
    $gains = @(0.26, 0.17, 0.1)
    for ($t = 0; $t -lt $delays.Length; $t++) {
        $d = [int]($delays[$t] * $SR)
        for ($i = $d; $i -lt $buf.Length; $i++) {
            $buf[$i] += $dry[$i - $d] * $gains[$t]
        }
    }
}


function Apply-HallEcho([double[]]$buf) {
    $dry = New-Object 'double[]' $buf.Length
    [array]::Copy($buf, $dry, $buf.Length)
    $delays = @(0.036, 0.058, 0.094, 0.141, 0.198)
    $gains = @(0.48, 0.4, 0.32, 0.24, 0.17)
    for ($t = 0; $t -lt $delays.Length; $t++) {
        $d = [int]($delays[$t] * $SR)
        $g = $gains[$t]
        for ($i = $d; $i -lt $buf.Length; $i++) {
            $buf[$i] += $dry[$i - $d] * $g
        }
    }
    $fb = [int](0.082 * $SR)
    $sm = 0.0
    for ($i = $fb; $i -lt $buf.Length; $i++) {
        $sm = $sm + 0.22 * ($buf[$i - $fb] - $sm)
        $buf[$i] += $sm * 0.38
    }
}

function Save-Wav([double[]]$buf, [string]$path) {
    $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $path))
    $fs = [System.IO.File]::Open($full, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter($fs)
    $n = $buf.Length
    $dataLen = $n * 2
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([int](36 + $dataLen))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([int]16)
    $bw.Write([int16]1)
    $bw.Write([int16]1)
    $bw.Write([int]$SR)
    $bw.Write([int]($SR * 2))
    $bw.Write([int16]2)
    $bw.Write([int16]16)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([int]$dataLen)
    for ($i = 0; $i -lt $n; $i++) {
        $v = $buf[$i]
        if ($v -gt 1.0) { $v = 1.0 }
        if ($v -lt -1.0) { $v = -1.0 }
        $bw.Write([int16][math]::Round($v * 32700.0))
    }
    $bw.Close()
    $fs.Close()
}

# ---------------- SFX tanimlari ----------------

# Ayak sesleri (4 varyant) — boguk gurultu + alcak thud
for ($k = 0; $k -lt 4; $k++) {
    $b = New-Buf 0.16
    Add-Noise $b 0.0 0.11 0.45 0.12 2.0
    Add-Tone $b (70 + $k * 6) (45 + $k * 4) 0.0 0.09 0.35 0.002 0.06 "sine"
    Save-Wav $b ("$sfxDir\footstep_" + ([char](97 + $k)) + ".wav")
}

# Flashlight click — cok kisa cift tik
$b = New-Buf 0.07
Add-Noise $b 0.0 0.012 0.6 0.9 3.0
Add-Tone $b 1800 900 0.0 0.012 0.3 0.0005 0.008 "square"
Add-Noise $b 0.03 0.012 0.4 0.9 3.0
Save-Wav $b "$sfxDir\flashlight_click.wav"

# Pickup — kalin kisa nota (esya ele alma / onemli bulgu hissi)
$b = New-Buf 0.9
Add-Tone $b 55 48 0.0 0.78 0.6 0.004 0.38 "sine"
Add-Tone $b 82 74 0.0 0.7 0.54 0.003 0.32 "sine"
Add-Tone $b 123 112 0.0 0.58 0.26 0.006 0.28 "sine"
Add-Tone $b 87 83 0.0 0.62 0.2 0.006 0.3 "sine"
Add-Noise $b 0.0 0.035 0.32 0.38 2.4
Add-Tone $b 65 50 0.0 0.14 0.42 0.001 0.11 "sine"
Save-Wav $b "$sfxDir\pickup.wav"

# Heal — yumusak nefes + alcak ton
$b = New-Buf 0.5
Add-Noise $b 0.0 0.45 0.18 0.06 1.2
Add-Tone $b 300 360 0.05 0.35 0.16 0.05 0.2 "sine"
Save-Wav $b "$sfxDir\heal.wav"

# UI paper / mesaj acilis — kagit hisirtisi
$b = New-Buf 0.2
Add-Noise $b 0.0 0.16 0.28 0.5 2.2
Add-Tone $b 1400 1100 0.0 0.05 0.05 0.002 0.04 "saw"
Save-Wav $b "$sfxDir\ui_paper.wav"

# UI open — hafif panel acilis (envanter / pause; ince, alcak)
$b = New-Buf 0.32
Add-Tone $b 62 55 0.0 0.28 0.38 0.008 0.18 "sine"
Add-Tone $b 93 86 0.0 0.22 0.22 0.006 0.14 "sine"
Add-Noise $b 0.0 0.05 0.18 0.22 2.0
Save-Wav $b "$sfxDir\ui_open.wav"

# Menu sting — temiz kalin synth + hafif echo (ana menu, az PSX)
$b = New-Buf 0.85
Add-Tone $b 55 47 0.0 0.6 0.64 0.014 0.4 "sine"
Add-Tone $b 55.6 47.8 0.0 0.58 0.42 0.014 0.38 "sine"
Add-Tone $b 82 73 0.0 0.52 0.36 0.012 0.34 "sine"
Add-Tone $b 110 99 0.0 0.45 0.2 0.014 0.3 "sine"
Add-Tone $b 27.5 23 0.0 0.65 0.58 0.016 0.46 "sine"
Add-Noise $b 0.0 0.02 0.1 0.38 3.0
Apply-SoftEcho $b
Save-Wav $b "$sfxDir\menu_sting.wav"

# UI close — agir kapanan kalin nota + reverse drone
$b = New-Buf 0.5
Add-Tone $b 48 32 0.0 0.45 0.55 0.01 0.3 "sine"
Add-Tone $b 72 50 0.0 0.35 0.28 0.01 0.25 "sine"
Add-Noise $b 0.0 0.06 0.25 0.2 2.5
Add-Tone $b 120 65 0.0 0.22 0.18 0.005 0.18 "saw"
Save-Wav $b "$sfxDir\ui_close.wav"

# Chapter sting — kalin dramatik bolum basligi notasi (RE / Silent Hill tarzi)
$b = New-Buf 2.4
Add-Tone $b 41 36 0.0 2.1 0.72 0.006 1.35 "sine"
Add-Tone $b 82 74 0.0 1.9 0.62 0.005 1.15 "sine"
Add-Tone $b 123 112 0.0 1.6 0.32 0.008 0.95 "sine"
Add-Tone $b 87 83 0.0 1.7 0.24 0.008 1.0 "sine"
Add-Tone $b 164 150 0.0 1.2 0.14 0.02 0.7 "sine"
Add-Noise $b 0.0 0.05 0.42 0.35 2.2
Add-Tone $b 55 42 0.0 0.18 0.55 0.001 0.14 "sine"
Save-Wav $b "$sfxDir\chapter_sting.wav"

# Kilitli kapi — metalik takirti + alcak thunk
$b = New-Buf 0.5
Add-Tone $b 90 60 0.0 0.18 0.4 0.002 0.12 "sine"
Add-Noise $b 0.0 0.04 0.5 0.7 2.0
Add-Noise $b 0.09 0.04 0.45 0.7 2.0
Add-Noise $b 0.17 0.05 0.4 0.6 2.0
Save-Wav $b "$sfxDir\door_locked.wav"

# Fuse install — alcak clunk + kucuk elektrik ziplama
$b = New-Buf 0.45
Add-Tone $b 120 70 0.0 0.14 0.45 0.001 0.1 "sine"
Add-Noise $b 0.0 0.05 0.4 0.6 2.5
Add-Noise $b 0.16 0.12 0.22 0.95 1.0
Add-Tone $b 1600 400 0.16 0.1 0.12 0.001 0.08 "saw"
Save-Wav $b "$sfxDir\fuse_install.wav"

# Power on — yukselen elektrik hum + flicker + thunk
$b = New-Buf 1.4
Add-Tone $b 50 60 0.0 1.2 0.22 0.4 0.3 "sine"
Add-Tone $b 100 120 0.0 1.2 0.12 0.4 0.3 "sine"
Add-Noise $b 0.0 0.18 0.18 0.95 1.0
Add-Noise $b 0.35 0.05 0.2 0.9 2.0
Add-Tone $b 140 90 0.0 0.16 0.4 0.001 0.12 "sine"
Save-Wav $b "$ambDir\power_on.wav"

# Exit sealed — agir reddedilmis metalik clank + buzz
$b = New-Buf 0.6
Add-Tone $b 110 70 0.0 0.22 0.5 0.001 0.15 "square"
Add-Noise $b 0.0 0.06 0.5 0.5 2.0
Add-Tone $b 220 210 0.05 0.4 0.1 0.02 0.3 "square"
Save-Wav $b "$sfxDir\exit_sealed.wav"

# Exit open — manyetik kilit acilir buzz + clunk + hava
$b = New-Buf 0.9
Add-Tone $b 240 230 0.0 0.35 0.16 0.02 0.2 "saw"
Add-Tone $b 130 90 0.32 0.18 0.45 0.001 0.12 "sine"
Add-Noise $b 0.32 0.05 0.4 0.6 2.0
Add-Noise $b 0.4 0.45 0.16 0.08 1.0
Save-Wav $b "$sfxDir\exit_open.wav"

# Enemy growl — alcak AM gurultu
$b = New-Buf 1.1
Add-Growl $b 0.0 1.05 0.5 7.0 3.0 0.10
Add-Tone $b 75 60 0.0 1.0 0.12 0.2 0.3 "sine"
Save-Wav $b "$sfxDir\enemy_growl.wav"

# Enemy alert — disonant yukselen sting
$b = New-Buf 0.7
Add-Tone $b 300 520 0.0 0.6 0.26 0.005 0.25 "saw"
Add-Tone $b 317 553 0.0 0.6 0.22 0.005 0.25 "saw"
Add-Noise $b 0.0 0.1 0.2 0.7 1.5
Save-Wav $b "$sfxDir\enemy_alert.wav"

# Enemy attack — whoosh + alcak vurus
$b = New-Buf 0.4
Add-Noise $b 0.0 0.18 0.4 0.4 1.0
Add-Tone $b 200 80 0.12 0.18 0.4 0.002 0.12 "sine"
Save-Wav $b "$sfxDir\enemy_attack.wav"

# Enemy hurt — kisa squelch + inen ton
$b = New-Buf 0.32
Add-Noise $b 0.0 0.14 0.5 0.5 1.8
Add-Tone $b 420 180 0.0 0.16 0.3 0.002 0.1 "saw"
Save-Wav $b "$sfxDir\enemy_hurt.wav"

# Enemy death — inen inilti
$b = New-Buf 0.9
Add-Tone $b 260 70 0.0 0.8 0.34 0.01 0.4 "saw"
Add-Growl $b 0.0 0.85 0.3 6.0 2.0 0.12
Save-Wav $b "$sfxDir\enemy_death.wav"

# Player hurt — alcak thud + boguk nefes
$b = New-Buf 0.4
Add-Tone $b 160 70 0.0 0.16 0.45 0.001 0.12 "sine"
Add-Noise $b 0.0 0.22 0.3 0.2 1.2
Save-Wav $b "$sfxDir\player_hurt.wav"

# Heartbeat — lub-dub (dusuk canda loop)
$b = New-Buf 1.1
Add-Tone $b 70 45 0.0 0.14 0.6 0.003 0.1 "sine"
Add-Tone $b 65 42 0.22 0.16 0.5 0.003 0.12 "sine"
Save-Wav $b "$sfxDir\heartbeat.wav"

# Gun fire — keskin atak + alcak govde
$b = New-Buf 0.35
Add-Noise $b 0.0 0.16 0.85 0.95 2.5
Add-Tone $b 240 70 0.0 0.12 0.5 0.0005 0.1 "sine"
Save-Wav $b "$sfxDir\gun_fire.wav"

# Gun empty — kuru klik
$b = New-Buf 0.08
Add-Noise $b 0.0 0.015 0.5 0.9 3.0
Add-Tone $b 1200 600 0.0 0.012 0.25 0.0005 0.008 "square"
Save-Wav $b "$sfxDir\gun_empty.wav"

# Reload — mekanik klikler
$b = New-Buf 0.5
Add-Noise $b 0.0 0.03 0.45 0.85 2.5
Add-Tone $b 700 500 0.0 0.025 0.2 0.001 0.02 "square"
Add-Noise $b 0.2 0.03 0.4 0.85 2.5
Add-Noise $b 0.36 0.04 0.5 0.8 2.5
Add-Tone $b 500 800 0.36 0.03 0.2 0.001 0.02 "square"
Save-Wav $b "$sfxDir\reload.wav"

# Knife swing — whoosh
$b = New-Buf 0.25
Add-Noise $b 0.0 0.16 0.4 0.35 1.2
Add-Tone $b 900 300 0.0 0.12 0.12 0.002 0.08 "saw"
Save-Wav $b "$sfxDir\knife_swing.wav"

# Knife hit — squelch
$b = New-Buf 0.25
Add-Noise $b 0.0 0.13 0.55 0.45 1.8
Add-Tone $b 220 110 0.0 0.1 0.3 0.002 0.08 "sine"
Save-Wav $b "$sfxDir\knife_hit.wav"

# Ambient drone — uzun alcak dron (loop)
$b = New-Buf 8.0
Add-Tone $b 55 55 0.0 8.0 0.22 1.0 1.0 "sine"
Add-Tone $b 82 82 0.0 8.0 0.12 1.5 1.5 "sine"
Add-Tone $b 110 110 0.0 8.0 0.07 2.0 2.0 "sine"
Add-Noise $b 0.0 8.0 0.06 0.02 0.0
# yavas ruzgar dalgalanmasi
for ($i = 0; $i -lt $b.Length; $i++) {
    $t = $i / [double]$SR
    $b[$i] *= (0.75 + 0.25 * [math]::Sin(2.0 * [math]::PI * 0.08 * $t))
}
Save-Wav $b "$ambDir\ambient_drone.wav"

Write-Host "SFX uretildi -> $sfxDir ve $ambDir"
Get-ChildItem $sfxDir, $ambDir -Filter *.wav | ForEach-Object { "{0} ({1} bytes)" -f $_.Name, $_.Length }
