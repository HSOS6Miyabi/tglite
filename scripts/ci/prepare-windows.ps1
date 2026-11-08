param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:TG_API_ID -notmatch '^[0-9]{4,12}$') {
    throw 'API_ID must contain the numeric application ID issued by Telegram.'
}
if ($env:TG_API_HASH -notmatch '^[0-9a-fA-F]{32}$') {
    throw 'API_HASH must contain the 32-character hexadecimal application hash.'
}
if ([string]::IsNullOrWhiteSpace($env:TG_PFX_B64)) {
    throw 'Repository secret PFX must contain the Base64-encoded signing certificate.'
}

$constantsFile = Join-Path $PWD 'Telegram/Constants.Secret.cs'
@"
namespace Telegram
{
    public static partial class Constants
    {
        static Constants()
        {
            ApiId = $($env:TG_API_ID);
            ApiHash = "$($env:TG_API_HASH)";
            AppChannel = "";
        }
    }
}
"@ | Set-Content -LiteralPath $constantsFile -Encoding utf8

$signingFile = Join-Path $env:RUNNER_TEMP 'tglite-signing.pfx'
try {
    $bytes = [Convert]::FromBase64String(($env:TG_PFX_B64 -replace '\s', ''))
    [System.IO.File]::WriteAllBytes($signingFile, $bytes)
}
catch {
    throw 'Repository secret PFX does not contain valid Base64 data.'
}

try {
    $password = New-Object System.Security.SecureString
    if (-not [string]::IsNullOrEmpty($env:TG_PFX_PASSWORD)) {
        $password = ConvertTo-SecureString -String $env:TG_PFX_PASSWORD -AsPlainText -Force
    }
    $certificates = @(Import-PfxCertificate -FilePath $signingFile -CertStoreLocation 'Cert:\CurrentUser\My' -Password $password -ErrorAction Stop)
    $certificate = $certificates | Where-Object { $_.HasPrivateKey } | Select-Object -First 1
    if ($null -eq $certificate) {
        throw 'PFX has no usable private key.'
    }
}
catch {
    throw 'Could not import PFX. If protected by a password, create a PFX_PASSWORD repository secret.'
}

if ($certificate.NotBefore -gt (Get-Date) -or $certificate.NotAfter -le (Get-Date)) {
    throw 'Signing certificate is not currently valid.'
}

$ekuExtension = $certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' } | Select-Object -First 1
if ($null -ne $ekuExtension) {
    $usageExtension = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($ekuExtension, $ekuExtension.Critical)
    $usageOids = @($usageExtension.EnhancedKeyUsages | ForEach-Object { $_.Value })
    if ($usageOids.Count -gt 0 -and $usageOids -notcontains '1.3.6.1.5.5.7.3.3' -and $usageOids -notcontains '2.5.29.37.0') {
        throw 'Signing certificate is not permitted for code signing.'
    }
}

$subject = $certificate.Subject.Replace("`r", '').Replace("`n", '')
if ([string]::IsNullOrWhiteSpace($subject)) {
    throw 'The signing certificate does not have a Publisher subject.'
}

$releasePath = Join-Path $PWD 'release'
New-Item -ItemType Directory -Force -Path $releasePath | Out-Null
Export-Certificate -Cert $certificate -FilePath (Join-Path $releasePath 'TGLite-Signing-Certificate.cer') -Type CERT -Force | Out-Null

@(
  "TGLITE_CERT_THUMBPRINT=$($certificate.Thumbprint)"
  "TGLITE_CERT_SUBJECT=$subject"
) | Add-Content -LiteralPath $env:GITHUB_ENV -Encoding utf8

Write-Host "Credentials configured; signing publisher: $subject"
Write-Host "Certificate expiration: $($certificate.NotAfter.ToString('yyyy-MM-dd'))"
Write-Host "Certificate thumbprint: $($certificate.Thumbprint)"
