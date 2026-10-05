<#
    .SYNOPSIS
        Genere les icones PNG du cadran dans resources/drawables/.
        Les glyphes sont rendus depuis les polices Windows (Segoe UI Emoji /
        Segoe UI Symbol) puis colorises, car Monkey C n'affiche pas les emojis.

    .DESCRIPTION
        Icones produites (fond transparent) :
          icon_steps.png     U+1F45F  chaussure   (bleu)
          icon_hr.png        U+1F493  coeur       (rouge)
          icon_bb.png        U+1F4AA  biceps      (vert)
          icon_stress.png    U+1F615  visage      (orange)
          icon_alarm_on.png  U+1F56D  cloche      (jaune  = alarme active)
          icon_alarm_off.png U+1F56D  cloche      (gris   = pas d'alarme)
          icon_moon_*.png    U+1F311..U+1F318 phases lunaires (Segoe UI Emoji)
          icon_weather_*.png glyphes meteo Zambretti (Segoe UI Emoji)

    .EXAMPLE
        .\scripts\make-icons.ps1
        .\scripts\make-icons.ps1 -IconSize 48
#>
param(
    [int]$IconSize = 40
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\resources\drawables'))
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function New-Icon {
    param(
        [string]$FileName,
        [int]$CodePoint,
        [int]$Rgb,
        [string]$FontName = 'Segoe UI Emoji',
        [int]$OutputSize = $IconSize,
        [double]$GlyphScale = 0.62,
        [switch]$EmojiPresentation,
        [switch]$Bold
    )

    $bmp = New-Object System.Drawing.Bitmap($OutputSize, $OutputSize)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)

    $glyph = [char]::ConvertFromUtf32($CodePoint)
    if ($EmojiPresentation) { $glyph += [char]0xFE0F }
    $fontStyle = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $font = New-Object System.Drawing.Font($FontName, ($OutputSize * $GlyphScale), $fontStyle, [System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'

    $g.DrawString($glyph, $font, [System.Drawing.Brushes]::White,
        (New-Object System.Drawing.RectangleF(0, 0, $OutputSize, $OutputSize)), $sf)
    $g.Dispose()

    # Colorisation : on garde l'alpha du glyphe, on force la teinte
    $color = [System.Drawing.Color]::FromArgb(255, ($Rgb -shr 16) -band 0xFF, ($Rgb -shr 8) -band 0xFF, $Rgb -band 0xFF)
    for ($y = 0; $y -lt $OutputSize; $y++) {
        for ($x = 0; $x -lt $OutputSize; $x++) {
            $px = $bmp.GetPixel($x, $y)
            if ($px.A -gt 0) {
                # seuil : evite les pixels quasi transparents (halo)
                $a = if ($px.A -lt 40) { 0 } else { 255 }
                $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $color.R, $color.G, $color.B))
            }
        }
    }

    $path = Join-Path $outDir $FileName
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  $FileName" -ForegroundColor DarkGray
}

Write-Host "Generation des icones ($IconSize x $IconSize) dans $outDir" -ForegroundColor Cyan
New-Icon -FileName 'icon_steps.png'     -CodePoint 0x1F45F -Rgb 0x00AAFF                              # chaussure
New-Icon -FileName 'icon_hr.png'        -CodePoint 0x1F493 -Rgb 0xFF3B30                              # coeur
New-Icon -FileName 'icon_bb.png'        -CodePoint 0x1F4AA -Rgb 0x34C759                              # biceps
New-Icon -FileName 'icon_stress.png'    -CodePoint 0x1F615 -Rgb 0xFF9500                              # visage inquiet
# Cloche d'alarme : pictogramme monochrome present dans Segoe UI Symbol
New-Icon -FileName 'icon_alarm_on.png'  -CodePoint 0x1F56D -Rgb 0xFFCC00 -FontName 'Segoe UI Symbol'  # alarme active
New-Icon -FileName 'icon_alarm_off.png' -CodePoint 0x1F56D -Rgb 0x555555 -FontName 'Segoe UI Symbol'  # pas d'alarme
New-Icon -FileName 'icon_moon_new.png'             -CodePoint 0x1F311 -Rgb 0xD9D4C7 -OutputSize 24 -GlyphScale 0.90 -EmojiPresentation -Bold # nouvelle lune
New-Icon -FileName 'icon_moon_waxing_crescent.png' -CodePoint 0x1F312 -Rgb 0xD9D4C7 -OutputSize 24 -GlyphScale 0.90 -EmojiPresentation -Bold # premier croissant
New-Icon -FileName 'icon_moon_first_quarter.png'   -CodePoint 0x1F313 -Rgb 0xD9D4C7 -OutputSize 24 -GlyphScale 0.90 -EmojiPresentation -Bold # premier quartier
New-Icon -FileName 'icon_moon_waxing_gibbous.png'  -CodePoint 0x1F314 -Rgb 0xD9D4C7 -OutputSize 24 -GlyphScale 0.90 -EmojiPresentation -Bold # lune gibbeuse croissante
New-Icon -FileName 'icon_moon_full.png'            -CodePoint 0x1F315 -Rgb 0xD9D4C7 -OutputSize 24 -GlyphScale 0.90 -EmojiPresentation -Bold # pleine lune
New-Icon -FileName 'icon_moon_waning_gibbous.png'  -CodePoint 0x1F316 -Rgb 0xD9D4C7 -OutputSize 24 -GlyphScale 0.90 -EmojiPresentation -Bold # lune gibbeuse decroissante
New-Icon -FileName 'icon_moon_last_quarter.png'    -CodePoint 0x1F317 -Rgb 0xD9D4C7 -OutputSize 24 -GlyphScale 0.90 -EmojiPresentation -Bold # dernier quartier
New-Icon -FileName 'icon_moon_waning_crescent.png' -CodePoint 0x1F318 -Rgb 0xD9D4C7 -OutputSize 24 -GlyphScale 0.90 -EmojiPresentation -Bold # dernier croissant
New-Icon -FileName 'icon_weather_stable.png'   -CodePoint 0x2600  -Rgb 0xFFD166 -GlyphScale 0.90 -EmojiPresentation -Bold # soleil : temps tres stable
New-Icon -FileName 'icon_weather_fair.png'     -CodePoint 0x1F31E -Rgb 0xFFD166 -GlyphScale 0.90 -EmojiPresentation -Bold # soleil avec visage : beau temps
New-Icon -FileName 'icon_weather_clouds.png'   -CodePoint 0x1F325 -Rgb 0xAAB6C4 -GlyphScale 0.90 -EmojiPresentation -Bold # soleil et nuage : eclaircies
New-Icon -FileName 'icon_weather_variable.png' -CodePoint 0x1F32C -Rgb 0x80CBC4 -GlyphScale 0.90 -EmojiPresentation -Bold # vent : temps variable
New-Icon -FileName 'icon_weather_showers.png'  -CodePoint 0x1F326 -Rgb 0x74C0FC -GlyphScale 0.90 -EmojiPresentation -Bold # averses
New-Icon -FileName 'icon_weather_rain.png'     -CodePoint 0x1F327 -Rgb 0x4DA3FF -GlyphScale 0.90 -EmojiPresentation -Bold # pluie
New-Icon -FileName 'icon_weather_storm.png'    -CodePoint 0x1F329 -Rgb 0xC080A0 -GlyphScale 0.90 -EmojiPresentation -Bold # nuage avec eclair
Write-Host "Termine." -ForegroundColor Green
