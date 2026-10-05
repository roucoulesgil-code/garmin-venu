<#
    .SYNOPSIS
        Compile puis lance l'application dans le simulateur Connect IQ.
    .EXAMPLE
        .\scripts\run.ps1 -Device venu3
#>
param(
    [ValidateSet('venu3', 'venu3s')]
    [string]$Device = 'venu3'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ciq-common.ps1')

& (Join-Path $PSScriptRoot 'build.ps1') -Device $Device

# Demarrage du simulateur s'il n'est pas deja lance
if (-not (Get-Process -Name 'simulator' -ErrorAction SilentlyContinue)) {
    Write-Host "Demarrage du simulateur..." -ForegroundColor Cyan
    Start-Process (Get-CiqSimulator)
    Start-Sleep -Seconds 5
}

$prg = Join-Path (Get-ProjectRoot) "bin\Garmin-$Device.prg"
Write-Host "Chargement de $prg sur $Device ..." -ForegroundColor Cyan
& (Get-CiqMonkeyDo) $prg $Device
