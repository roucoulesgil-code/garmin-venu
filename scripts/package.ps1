<#
    .SYNOPSIS
        Genere le fichier .iq a deposer sur le Connect IQ Store (tous appareils).
#>
param(
    [string]$KeyPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ciq-common.ps1')

$root   = Get-ProjectRoot
$binDir = Join-Path $root 'bin'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

$output = Join-Path $binDir 'Garmin-venu-1.iq'

Write-Host "Packaging du .iq ..." -ForegroundColor Cyan
& (Get-CiqCompiler) `
    -f (Join-Path $root 'monkey.jungle') `
    -o $output `
    -y (Get-CiqDeveloperKey -KeyPath $KeyPath) `
    -e `
    -r `
    -w

if ($LASTEXITCODE -ne 0) { throw "Echec du packaging ($LASTEXITCODE)" }
Write-Host "OK -> $output" -ForegroundColor Green
