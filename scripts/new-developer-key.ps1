<#
    .SYNOPSIS
        Genere la cle developpeur Connect IQ (developer_key.der, RSA PKCS#8 DER non chiffre).

    .DESCRIPTION
        Deux strategies, dans l'ordre :
          1. .NET Core 3.0+ (PowerShell 7+) : RSA.ExportPkcs8PrivateKey()
          2. Repli universel (PowerShell 5.1) : encodage ASN.1/DER realise par le script
        Aucune dependance a openssl. openssl, s'il est present, sert uniquement a verifier.
        La cle ne doit JAMAIS etre commitee (voir .gitignore).

    .EXAMPLE
        .\scripts\new-developer-key.ps1
        .\scripts\new-developer-key.ps1 -KeySize 4096 -Force
#>
param(
    [string]$OutFile = (Join-Path $PSScriptRoot '..\developer_key.der'),
    [ValidateSet(2048, 3072, 4096)]
    [int]$KeySize = 4096,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$OutFile = [System.IO.Path]::GetFullPath($OutFile)

if ((Test-Path $OutFile) -and -not $Force) {
    Write-Warning "La cle existe deja : $OutFile"
    Write-Warning "Utilisez -Force pour la regenerer (une application deja publiee avec l'ancienne cle devrait etre republiee)."
    return
}

# ---------------------------------------------------------------------------
# Encodeur ASN.1 / DER minimal (necessaire sous PowerShell 5.1)
# ---------------------------------------------------------------------------
function New-DerTlv {
    param([byte]$Tag, [byte[]]$Content)

    $out = New-Object 'System.Collections.Generic.List[byte]'
    $out.Add($Tag)

    $len = $Content.Length
    if ($len -lt 0x80) {
        $out.Add([byte]$len)
    } else {
        $lenBytes = New-Object 'System.Collections.Generic.List[byte]'
        $v = $len
        while ($v -gt 0) {
            $lenBytes.Insert(0, [byte]($v -band 0xFF))
            $v = $v -shr 8
        }
        $out.Add([byte](0x80 -bor $lenBytes.Count))
        $out.AddRange($lenBytes)
    }

    if ($len -gt 0) { $out.AddRange($Content) }
    return ,$out.ToArray()
}

function New-DerInteger {
    param([byte[]]$Value)

    # Zeros de tete supprimes, puis bourrage 0x00 si le bit de poids fort est a 1
    # (un INTEGER DER est signe : il doit rester positif).
    $i = 0
    while ($i -lt ($Value.Length - 1) -and $Value[$i] -eq 0) { $i++ }

    $content = New-Object 'System.Collections.Generic.List[byte]'
    if (($Value[$i] -band 0x80) -ne 0) { $content.Add([byte]0) }
    for ($j = $i; $j -lt $Value.Length; $j++) { $content.Add($Value[$j]) }

    return ,(New-DerTlv -Tag 0x02 -Content $content.ToArray())
}

function ConvertTo-Pkcs8Der {
    param([System.Security.Cryptography.RSAParameters]$Parameters)

    # RSAPrivateKey ::= SEQUENCE { version, n, e, d, p, q, dP, dQ, qInv }
    $seq = New-Object 'System.Collections.Generic.List[byte]'
    $seq.AddRange((New-DerInteger -Value ([byte[]]@(0))))
    $seq.AddRange((New-DerInteger -Value $Parameters.Modulus))
    $seq.AddRange((New-DerInteger -Value $Parameters.Exponent))
    $seq.AddRange((New-DerInteger -Value $Parameters.D))
    $seq.AddRange((New-DerInteger -Value $Parameters.P))
    $seq.AddRange((New-DerInteger -Value $Parameters.Q))
    $seq.AddRange((New-DerInteger -Value $Parameters.DP))
    $seq.AddRange((New-DerInteger -Value $Parameters.DQ))
    $seq.AddRange((New-DerInteger -Value $Parameters.InverseQ))
    $rsaPrivateKey = New-DerTlv -Tag 0x30 -Content $seq.ToArray()

    # AlgorithmIdentifier ::= SEQUENCE { OID 1.2.840.113549.1.1.1 (rsaEncryption), NULL }
    $algId = [byte[]]@(0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00)

    # PrivateKeyInfo ::= SEQUENCE { version, algorithm, privateKey OCTET STRING }
    $info = New-Object 'System.Collections.Generic.List[byte]'
    $info.AddRange((New-DerInteger -Value ([byte[]]@(0))))
    $info.AddRange($algId)
    $info.AddRange((New-DerTlv -Tag 0x04 -Content $rsaPrivateKey))

    return ,(New-DerTlv -Tag 0x30 -Content $info.ToArray())
}

# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------
$parent = Split-Path $OutFile -Parent
if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }

Write-Host "Generation d'une cle RSA $KeySize bits ... (quelques secondes)" -ForegroundColor Cyan

$der = $null
$method = ''
$rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider($KeySize)
try {
    $rsa.PersistKeyInCsp = $false

    if ($rsa.PSObject.Methods.Name -contains 'ExportPkcs8PrivateKey') {
        $der = $rsa.ExportPkcs8PrivateKey()          # PowerShell 7+ / .NET Core 3.0+
        $method = '.NET ExportPkcs8PrivateKey'
    } else {
        $der = ConvertTo-Pkcs8Der -Parameters $rsa.ExportParameters($true)
        $method = 'encodeur DER integre'
    }
} finally {
    $rsa.Dispose()
}

if ($null -eq $der -or $der.Length -lt 100) {
    throw "Echec de la generation de la cle."
}

[System.IO.File]::WriteAllBytes($OutFile, $der)

# Controle facultatif si openssl est disponible
if (Get-Command openssl -ErrorAction SilentlyContinue) {
    $check = & openssl rsa -inform DER -in $OutFile -noout -check 2>&1
    if ($LASTEXITCODE -ne 0) {
        Remove-Item $OutFile -Force
        throw "La cle generee est invalide : $check"
    }
    Write-Host "Verification openssl : OK" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Cle developpeur generee ($method)" -ForegroundColor Green
Write-Host "  Fichier : $OutFile"
Write-Host "  Taille  : $($der.Length) octets (RSA $KeySize bits, PKCS#8 DER)"
Write-Host ""
Write-Host "IMPORTANT : conservez une sauvegarde de cette cle hors du depot git." -ForegroundColor Yellow
Write-Host "Etape suivante : .\scripts\build.ps1 -Device venu3" -ForegroundColor Cyan