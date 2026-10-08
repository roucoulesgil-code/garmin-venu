<#
    .SYNOPSIS
        Compile l'application Connect IQ pour un appareil donne.
    .EXAMPLE
        .\scripts\build.ps1 -Device venu3
        .\scripts\build.ps1 -Device venu3s -Release
#>
param(
    [ValidateSet('venu3', 'venu3s')]
    [string]$Device = 'venu3',
    [switch]$Release,
    [string]$KeyPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ciq-common.ps1')

$root   = Get-ProjectRoot
$binDir = Join-Path $root 'bin'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

$output = Join-Path $binDir "Garmin-venu-1-$Device.prg"

$cmdArgs = @(
    '-f', (Join-Path $root 'monkey.jungle'),
    '-d', $Device,
    '-o', $output,
    '-y', (Get-CiqDeveloperKey -KeyPath $KeyPath),
    '-l', '3'
)
if ($Release) { $cmdArgs += '-r' } else { $cmdArgs += '--warn' }

Write-Host "Compilation pour $Device ..." -ForegroundColor Cyan
& (Get-CiqCompiler) @cmdArgs
if ($LASTEXITCODE -ne 0) { throw "Echec de la compilation ($LASTEXITCODE)" }

Write-Host "OK -> $output" -ForegroundColor Green
