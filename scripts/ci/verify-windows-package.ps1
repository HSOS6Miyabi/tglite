param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$packages = Join-Path $PWD 'Telegram/AppPackages'
$bundles = @(Get-ChildItem -Path $packages -Filter '*.msixbundle' -File -Recurse)
if ($bundles.Count -ne 1) {
    throw "Expected exactly one signed MSIXBundle; found $($bundles.Count)."
}
$bundle = $bundles[0]
$output = Join-Path $PWD 'release'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$asset = Join-Path $output ("TGLite-" + $env:TGLITE_PACKAGE_VERSION + "-x64.msixbundle")
Copy-Item -LiteralPath $bundle.FullName -Destination $asset -Force

$sdkBin = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$tools = @(Get-ChildItem -LiteralPath $sdkBin -Filter 'signtool.exe' -File -Recurse |
    Where-Object { $_.DirectoryName -match '[\\/]x64$' } | Sort-Object FullName -Descending)
if ($tools.Count -lt 1) { throw 'Windows SDK SignTool is unavailable.' }
$signTool = $tools[0].FullName

$cer = Join-Path $output 'TGLite-Signing-Certificate.cer'
if (-not (Test-Path -LiteralPath $cer)) { throw 'The public signing certificate is missing.' }
Import-Certificate -FilePath $cer -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null

& $signTool verify /pa /v $asset
if ($LASTEXITCODE -ne 0) { throw 'The MSIXBundle digital signature failed verification.' }

$signature = Get-AuthenticodeSignature -LiteralPath $asset
if (-not $signature.SignerCertificate -or $signature.SignerCertificate.Thumbprint -ne $env:TGLITE_CERT_THUMBPRINT) {
    throw 'The package signature uses a different certificate than PFX.'
}

$metadata = [ordered]@{
    project = 'TGLite'
    architecture = 'x64'
    package_version = $env:TGLITE_PACKAGE_VERSION
    release_tag = $env:TGLITE_RELEASE_TAG
    upstream_commit = (Get-Content 'scripts/upstream-ref.txt' -Raw).Trim()
    source_commit = $env:GITHUB_SHA
    workflow_run = "$($env:GITHUB_SERVER_URL)/$($env:GITHUB_REPOSITORY)/actions/runs/$($env:GITHUB_RUN_ID)"
    signing_certificate_subject = $env:TGLITE_CERT_SUBJECT
    signing_certificate_thumbprint = $env:TGLITE_CERT_THUMBPRINT
    checks = @('Source checks', 'Roslyn syntax checks', 'Windows x64 MSIXBundle build', 'Package signature verification')
}
$metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'BUILD-INFO.json') -Encoding utf8

$dependencies = @(Get-ChildItem -Path $packages -Filter '*.appx' -File -Recurse |
    Where-Object { $_.FullName -match '[\\/]Dependencies[\\/]' })
if ($dependencies.Count -gt 0) {
    $dependencyDir = Join-Path $output 'Dependencies'
    New-Item -ItemType Directory -Path $dependencyDir -Force | Out-Null
    foreach ($file in $dependencies) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $dependencyDir $file.Name)
    }
    Compress-Archive -Path (Join-Path $dependencyDir '*') -DestinationPath (Join-Path $output ("TGLite-" + $env:TGLITE_PACKAGE_VERSION + "-dependencies.zip")) -Force
    Remove-Item -LiteralPath $dependencyDir -Recurse -Force
}

$hashes = @(Get-ChildItem -LiteralPath $output -File | ForEach-Object {
    $sha = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$sha  $($_.Name)"
})
$hashes | Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt') -Encoding ascii
Write-Host "Verified signed package: $asset"
