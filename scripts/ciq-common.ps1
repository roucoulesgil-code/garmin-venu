<#
    Fonctions communes aux scripts de build Connect IQ.
    Resout automatiquement le SDK courant installe via le SDK Manager Garmin.
#>

function Get-CiqSdkPath {
    if ($env:CIQ_SDK_HOME -and (Test-Path $env:CIQ_SDK_HOME)) {
        return $env:CIQ_SDK_HOME.TrimEnd('\')
    }

    $cfg = Join-Path $env:APPDATA 'Garmin\ConnectIQ\current-sdk.cfg'
    if (Test-Path $cfg) {
        $sdk = (Get-Content $cfg -Raw).Trim()
        if (Test-Path $sdk) { return $sdk.TrimEnd('\') }
    }

    throw "SDK Connect IQ introuvable. Installez-le via le SDK Manager Garmin ou definissez `$env:CIQ_SDK_HOME."
}

function Get-CiqCompiler {
    $exe = Join-Path (Get-CiqSdkPath) 'bin\monkeyc.bat'
    if (-not (Test-Path $exe)) { throw "monkeyc introuvable : $exe" }
    return $exe
}

function Get-CiqSimulator {
    $exe = Join-Path (Get-CiqSdkPath) 'bin\simulator.exe'
    if (-not (Test-Path $exe)) { throw "simulator.exe introuvable : $exe" }
    return $exe
}

function Get-CiqMonkeyDo {
    $exe = Join-Path (Get-CiqSdkPath) 'bin\monkeydo.bat'
    if (-not (Test-Path $exe)) { throw "monkeydo introuvable : $exe" }
    return $exe
}

function Get-CiqDeveloperKey {
    param([string]$KeyPath)

    if ([string]::IsNullOrWhiteSpace($KeyPath)) {
        $KeyPath = Join-Path $PSScriptRoot '..\developer_key.der'
    }
    $KeyPath = [System.IO.Path]::GetFullPath($KeyPath)

    if (-not (Test-Path $KeyPath)) {
        Write-Warning "Cle developpeur absente : $KeyPath -> generation automatique."
        & (Join-Path $PSScriptRoot 'new-developer-key.ps1') -OutFile $KeyPath
        if (-not (Test-Path $KeyPath)) {
            throw "Impossible de generer la cle developpeur : $KeyPath"
        }
    }
    return $KeyPath
}

function Get-ProjectRoot {
    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}
