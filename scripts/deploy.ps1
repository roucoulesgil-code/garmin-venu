<#
    .SYNOPSIS
        Installe le cadran (.prg) sur une Garmin Venu 3 connectee en USB.

    .DESCRIPTION
        La Venu 3 se monte en MTP (pas de lettre de lecteur) : le script copie le
        fichier .prg dans GARMIN\APPS via l'API Shell de Windows.
        Si la montre apparait comme disque amovible, la copie est directe.

    .EXAMPLE
        .\scripts\deploy.ps1                       # build venu3 + copie sur la montre
        .\scripts\deploy.ps1 -SkipBuild
        .\scripts\deploy.ps1 -DeviceName 'Venu 3S' -Device venu3s
#>
param(
    [ValidateSet('venu3', 'venu3s')]
    [string]$Device = 'venu3',
    [string]$DeviceName = 'Venu',
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ciq-common.ps1')

# 1. Compilation -----------------------------------------------------------
if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'build.ps1') -Device $Device
}

$prg = Join-Path (Get-ProjectRoot) "bin\Garmin-venu-1-$Device.prg"
if (-not (Test-Path $prg)) { throw "Fichier introuvable : $prg (lancez d'abord build.ps1)" }

# 2. Cas 1 : montre montee comme disque amovible ---------------------------
$drive = Get-PSDrive -PSProvider FileSystem |
    Where-Object { Test-Path (Join-Path $_.Root 'GARMIN\APPS') } |
    Select-Object -First 1

if ($drive) {
    $dest = Join-Path $drive.Root 'GARMIN\APPS'
    Copy-Item $prg -Destination $dest -Force
    Write-Host "Copie dans $dest" -ForegroundColor Green
    Write-Host "Debranchez la montre : le cadran apparait dans Apparence > Cadran de montre." -ForegroundColor Cyan
    return
}

# 3. Cas 2 : montre en MTP -------------------------------------------------
$shell = New-Object -ComObject Shell.Application
$computer = $shell.NameSpace(17)   # ssfDRIVES = Ce PC
if ($computer -eq $null) { throw "Impossible d'acceder a 'Ce PC'." }

$watch = $computer.Items() | Where-Object { $_.Name -like "*$DeviceName*" } | Select-Object -First 1
if ($watch -eq $null) {
    throw "Montre '$DeviceName' introuvable. Branchez-la en USB, deverrouillez-la et autorisez l'acces aux donnees."
}
Write-Host "Montre detectee : $($watch.Name)" -ForegroundColor Cyan

function Get-SubFolder($folder, [string]$name) {
    if ($folder -eq $null) { return $null }
    $item = $folder.Items() | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if ($item -eq $null) { return $null }
    return $item.GetFolder
}

$root = $watch.GetFolder
# Chemin typique : <Montre>\Internal Storage\GARMIN\APPS
$storage = $root.Items() | Where-Object { $_.IsFolder } | Select-Object -First 1
$level = if ($storage -ne $null) { $storage.GetFolder } else { $root }

$garmin = Get-SubFolder $level 'GARMIN'
if ($garmin -eq $null) { $garmin = Get-SubFolder $root 'GARMIN' }
if ($garmin -eq $null) { throw "Dossier GARMIN introuvable sur la montre." }

$apps = Get-SubFolder $garmin 'APPS'
if ($apps -eq $null) { throw "Dossier GARMIN\APPS introuvable sur la montre." }

Write-Host "Copie de $(Split-Path $prg -Leaf) vers GARMIN\APPS ..." -ForegroundColor Cyan
$apps.CopyHere($prg, 16)   # 16 = repondre Oui a toutes les confirmations
Start-Sleep -Seconds 4

Write-Host "Termine. Debranchez la montre, puis :" -ForegroundColor Green
Write-Host "  Appui long sur le cadran > Modifier / ou Parametres > Apparence > Cadran de montre" -ForegroundColor Cyan
