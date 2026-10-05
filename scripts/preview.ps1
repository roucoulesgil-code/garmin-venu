<#
    .SYNOPSIS
        Genere un apercu PNG du cadran (maquette) avec les memes proportions
        que Venu3WatchFaceView.mc, pour visualiser la mise en page sans le SDK.
    .EXAMPLE
        .\scripts\preview.ps1 -Size 454        # Venu 3
        .\scripts\preview.ps1 -Size 390        # Venu 3S
#>
param(
    [int]$Size = 454,
    [int]$Steps = 7540,
    [int]$StepGoal = 10000,
    [int]$Hr = 72,
    [int]$Battery = 82,
    [int]$Altitude = 127,
    [int]$Pressure = 1013,
    [ValidateSet('rising', 'steady', 'falling')]
    [string]$PressureTrend = 'steady',
    [double]$MoonPhase = 0.25,
    [int]$BodyBattery = 68,
    [int]$Stress = 31,
    [switch]$AlarmActive = $true
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$W = $Size
$bmp = New-Object System.Drawing.Bitmap($W, $W)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::Black)

function New-Color([int]$rgb) {
    [System.Drawing.Color]::FromArgb(255, ($rgb -shr 16) -band 0xFF, ($rgb -shr 8) -band 0xFF, $rgb -band 0xFF)
}

function Get-ZambrettiState([double]$pressureHpa, [string]$trend, [double]$altitudeM) {
    $pressureHpa = $pressureHpa / [math]::Pow(1.0 - ($altitudeM / 44330.0), 5.255)

    if ($trend -eq 'rising') {
        $z = [math]::Max(20, [math]::Min(32, 179 - $pressureHpa / 6.45))
    } elseif ($trend -eq 'falling') {
        $z = [math]::Max(1, [math]::Min(9, 130 - $pressureHpa / 8.1))
    } else {
        $z = [math]::Max(10, [math]::Min(19, 147 - $pressureHpa / 7.52))
    }

    $zIndex = [int][math]::Floor($z + 0.5)
    $letters = @('', 'A', 'D', 'D', 'H', 'O', 'R', 'U', 'V', 'X', 'A', 'B', 'E', 'K', 'N', 'P', 'S', 'W', 'X', 'Z', 'A', 'B', 'C', 'F', 'G', 'I', 'J', 'L', 'M', 'Q', 'T', 'Y', 'Z')
    $letter = $letters[$zIndex]

    if ($letter -eq 'A') { $state = 0 }
    elseif ($letter -in @('B', 'C')) { $state = 1 }
    elseif ($letter -in @('D', 'E', 'F', 'G', 'H', 'I')) { $state = 2 }
    elseif ($letter -in @('J', 'K', 'L', 'M', 'N', 'O')) { $state = 3 }
    elseif ($letter -in @('P', 'Q', 'R')) { $state = 4 }
    elseif ($letter -in @('S', 'T', 'U', 'V', 'W', 'X')) { $state = 5 }
    else { $state = 6 }
    return [pscustomobject]@{ State = $state }
}

$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = 'Center'
$sf.LineAlignment = 'Center'

# Bord de l'ecran rond
$g.DrawEllipse((New-Object System.Drawing.Pen((New-Color 0x202020), 2)), 1, 1, $W - 2, $W - 2)

# Jauge batterie de la montre : quart superieur du cercle
$batteryRadius = [int]($W * 0.46)
$batteryRect = New-Object System.Drawing.RectangleF(($W / 2 - $batteryRadius), ($W / 2 - $batteryRadius), (2 * $batteryRadius), (2 * $batteryRadius))
$batteryTrack = New-Object System.Drawing.Pen((New-Color 0x303030), 4)
$g.DrawArc($batteryTrack, $batteryRect, -135, 90)
$batteryRatio = [math]::Max(0.0, [math]::Min(1.0, $Battery / 100.0))
if ($batteryRatio -gt 0) {
    $batteryProgress = New-Object System.Drawing.Pen((New-Color 0x34C759), 4)
    $batteryProgress.StartCap = 'Round'; $batteryProgress.EndCap = 'Round'
    $g.DrawArc($batteryProgress, $batteryRect, -135, (90 * $batteryRatio))
}

# Date : "9 - VEN"
$fDate = New-Object System.Drawing.Font('Arial', ($W * 0.052), [System.Drawing.FontStyle]::Regular)
$g.DrawString('9 - VEN', $fDate, (New-Object System.Drawing.SolidBrush((New-Color 0xAAAAAA))),
    (New-Object System.Drawing.RectangleF(0, ($W * 0.13), $W, ($W * 0.08))), $sf)

# Phase lunaire (fraction du cycle entre 0 et 1)
$moonPhase = $MoonPhase - [math]::Floor($MoonPhase)
$moonIcons = @('icon_moon_new.png', 'icon_moon_waxing_crescent.png', 'icon_moon_first_quarter.png', 'icon_moon_waxing_gibbous.png', 'icon_moon_full.png', 'icon_moon_waning_gibbous.png', 'icon_moon_last_quarter.png', 'icon_moon_waning_crescent.png')
$moonPhaseIndex = [int][math]::Floor($moonPhase * 8 + 0.5)
if ($moonPhaseIndex -ge 8) { $moonPhaseIndex = 0 }
$moonIconPath = Join-Path $PSScriptRoot ("..\resources\drawables\" + $moonIcons[$moonPhaseIndex])
$moonIcon = [System.Drawing.Bitmap]::FromFile([System.IO.Path]::GetFullPath($moonIconPath))
$moonX = [int]($W / 2)
$moonY = [int]($W * 0.235)
$g.DrawImage($moonIcon, ($moonX - 12), ($moonY - 12), 24, 24)
$moonIcon.Dispose()

# Heure
$fTime = New-Object System.Drawing.Font('Arial', ($W * 0.20), [System.Drawing.FontStyle]::Bold)
$g.DrawString('10:42', $fTime, [System.Drawing.Brushes]::White,
    (New-Object System.Drawing.RectangleF(0, ($W * 0.40 - $W * 0.13), $W, ($W * 0.26))), $sf)

# Icone alarme
$cx = [int]($W / 2 - 46)
$cy = [int]($W * 0.235)
$r  = [int]($W * 0.030)
$alarmBrush = New-Object System.Drawing.SolidBrush((New-Color $(if ($AlarmActive) { 0xFFCC00 } else { 0x555555 })))
$g.FillEllipse($alarmBrush, ($cx - $r), ($cy - $r), (2 * $r), (2 * $r))
$g.FillRectangle($alarmBrush, ($cx - $r), $cy, (2 * $r), ([int]($r / 2) + 1))
$g.FillRectangle($alarmBrush, ($cx - $r - 3), ($cy + [int]($r / 2)), (2 * $r + 6), 3)
$g.FillEllipse($alarmBrush, ($cx - 3), ($cy + [int]($r / 2) + 2), 6, 6)

# 4 jauges
$radius  = [int]($W * 0.082)
$spacing = [int]($W * 0.23)
$gy      = [int]($W * 0.64)
$gx0     = [int]($W / 2 - ($spacing * 3) / 2)

# Pictogrammes des jauges (code points : independant de l'encodage du fichier .ps1)
# ATTENTION : ne pas nommer ces variables $Steps/$Hr/$Stress (parametres typés [int]).
$shoe    = [char]::ConvertFromUtf32(0x1F45F)  # chaussure
$heart   = [char]::ConvertFromUtf32(0x1F493)  # coeur battant
$body    = [char]::ConvertFromUtf32(0x1F4AA)  # bras flechi
$stressI = [char]::ConvertFromUtf32(0x1F615)  # visage inquiet

$gauges = @(
    @{ x = $gx0;                 ratio = [math]::Min(1.0, $Steps / [double]$StepGoal); color = 0x00AAFF; value = "$([math]::Round($Steps/1000,1))k"; label = $shoe },
    @{ x = $gx0 + $spacing;      ratio = [math]::Max(0.0, ($Hr - 40) / 140.0);         color = 0xFF3B30; value = "$Hr";  label = $heart },
    @{ x = $gx0 + $spacing * 2;  ratio = $BodyBattery / 100.0;                         color = 0x34C759; value = "$BodyBattery"; label = $body },
    @{ x = $gx0 + $spacing * 3;  ratio = $Stress / 100.0;                              color = 0xFF9500; value = "$Stress"; label = $stressI }
)

$penWidth = [math]::Max(3, [int]($radius * 0.28))
$fVal = New-Object System.Drawing.Font('Arial', ($W * 0.038))
$fLab = New-Object System.Drawing.Font('Arial', ($W * 0.030))
# Polices capables d'afficher les pictogrammes
$fEmoji  = New-Object System.Drawing.Font('Segoe UI Emoji', ($W * 0.036))   # emojis hors BMP (chaussure)
$fSymbol = New-Object System.Drawing.Font('Segoe UI Symbol', ($W * 0.044))  # symboles BMP (coeur U+2661)

foreach ($gauge in $gauges) {
    $x = [int]$gauge.x
    $rect = New-Object System.Drawing.RectangleF(($x - $radius), ($gy - $radius), (2 * $radius), (2 * $radius))

    # anneau de fond
    $g.DrawEllipse((New-Object System.Drawing.Pen((New-Color 0x303030), $penWidth)), $rect)

    # arc de progression : horaire depuis midi (-90 deg en GDI+)
    if ($gauge.ratio -gt 0) {
        $sweep = [math]::Min(360, 360 * $gauge.ratio)
        $pen = New-Object System.Drawing.Pen((New-Color $gauge.color), $penWidth)
        $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
        $g.DrawArc($pen, $rect, -90, $sweep)
    }

    $g.DrawString($gauge.value, $fVal, [System.Drawing.Brushes]::White,
        (New-Object System.Drawing.RectangleF(($x - $radius), ($gy - $radius), (2 * $radius), (2 * $radius))), $sf)

    # Libelle : police adaptee au type de caractere (emoji / symbole / texte)
    $labelFont = $fLab
    if ([System.Char]::IsHighSurrogate($gauge.label[0])) {
        $labelFont = $fEmoji          # emoji hors BMP (chaussure)
    } elseif ($gauge.label -match '[^\x20-\x7E]') {
        $labelFont = $fSymbol         # symbole BMP (coeur)
    }
    $g.DrawString($gauge.label, $labelFont, (New-Object System.Drawing.SolidBrush((New-Color $gauge.color))),
        (New-Object System.Drawing.RectangleF(($x - $radius), ($gy + $radius), (2 * $radius), ($W * 0.07))), $sf)
}

# Altitude et symbole de montagne sous les jauges
$altitudeBaseY = [int]($W * 0.92)
$metricRowHeight = [int]($W * 0.032)
$altitudeY = $altitudeBaseY - $metricRowHeight
$mountainCenterY = $altitudeBaseY - [int]($metricRowHeight / 2)
$mountainPen = New-Object System.Drawing.Pen((New-Color 0xC080A0), 2)
$mountainX = [int]($W / 2 - 22)
$mountainBottom = $mountainCenterY + 4
$mountainTop = $mountainCenterY - 4
$g.DrawLine($mountainPen, $mountainX, $mountainBottom, ($mountainX + 5), $mountainTop)
$g.DrawLine($mountainPen, ($mountainX + 5), $mountainTop, ($mountainX + 10), $mountainBottom)
$g.DrawLine($mountainPen, ($mountainX + 7), $mountainBottom, ($mountainX + 12), ($mountainBottom - 6))
$g.DrawLine($mountainPen, ($mountainX + 12), ($mountainBottom - 6), ($mountainX + 17), $mountainBottom)
$fAltitude = New-Object System.Drawing.Font('Arial', ($W * 0.020))
$sfAltitude = New-Object System.Drawing.StringFormat
$sfAltitude.Alignment = 'Near'
$sfAltitude.LineAlignment = 'Center'
$g.DrawString("$($Altitude)m", $fAltitude, (New-Object System.Drawing.SolidBrush((New-Color 0xC080A0))),
    (New-Object System.Drawing.RectangleF(($W / 2 + 5), $altitudeY, ($W * 0.18), $metricRowHeight)), $sfAltitude)

# Icône météo issue du calcul Zambretti
$weatherResult = Get-ZambrettiState -pressureHpa $Pressure -trend $PressureTrend -altitudeM $Altitude
$weatherState = $weatherResult.State
$weatherIcons = @('icon_weather_stable.png', 'icon_weather_fair.png', 'icon_weather_clouds.png', 'icon_weather_variable.png', 'icon_weather_showers.png', 'icon_weather_rain.png', 'icon_weather_storm.png')
$weatherIconPath = Join-Path $PSScriptRoot ("..\resources\drawables\" + $weatherIcons[$weatherState])
$weatherIcon = [System.Drawing.Bitmap]::FromFile([System.IO.Path]::GetFullPath($weatherIconPath))
$weatherX = [int]($W / 2 + 46)
$weatherY = [int]($W * 0.235)
$g.DrawImage($weatherIcon, ($weatherX - 20), ($weatherY - 20), 40, 40)
$weatherIcon.Dispose()

$g.Dispose()

$outDir = Join-Path $PSScriptRoot '..\preview'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$out = Join-Path $outDir "venu3-preview-$W.png"
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Apercu genere : $out" -ForegroundColor Green
