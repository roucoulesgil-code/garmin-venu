<#
    .SYNOPSIS
        Compile et execute les tests unitaires Zambretti dans le simulateur Connect IQ.
    .EXAMPLE
        .\scripts\test-zambretti.ps1 -Device venu3s
#>
param(
    [ValidateSet('venu3', 'venu3s')]
    [string]$Device = 'venu3s',
    [string]$KeyPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ciq-common.ps1')

$root = Get-ProjectRoot
$binDir = Join-Path $root 'bin'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
$output = Join-Path $binDir "Garmin-$Device-tests.prg"

$cmdArgs = @(
    '-f', (Join-Path $root 'monkey.jungle'),
    '-d', $Device,
    '-o', $output,
    '-y', (Get-CiqDeveloperKey -KeyPath $KeyPath),
    '-l', '3',
    '-t'
)

Write-Host "Compilation des tests Zambretti pour $Device ..." -ForegroundColor Cyan
& (Get-CiqCompiler) @cmdArgs
if ($LASTEXITCODE -ne 0) { throw "Echec de la compilation des tests ($LASTEXITCODE)" }

if (-not (Get-Process -Name 'simulator' -ErrorAction SilentlyContinue)) {
    Write-Host 'Demarrage du simulateur...' -ForegroundColor Cyan
    Start-Process (Get-CiqSimulator)
}

Write-Host "Execution des tests sur $Device ..." -ForegroundColor Cyan
& (Get-CiqMonkeyDo) $output $Device '/t'
if ($LASTEXITCODE -ne 0) { throw "Echec des tests Zambretti ($LASTEXITCODE)" }
