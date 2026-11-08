param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$release = Join-Path $PWD 'release'
$bundle = @(Get-ChildItem $release -Filter '*.msixbundle' -File | Select-Object -First 1)
if ($bundle.Count -ne 1) { throw 'Missing MSIXBundle for installation test.' }
$certificateFile = Join-Path $release 'TGLite-Signing-Certificate.cer'
if (-not (Test-Path $certificateFile)) { throw 'Missing public signing certificate.' }

Import-Certificate -FilePath $certificateFile -CertStoreLocation 'Cert:\CurrentUser\TrustedPeople' | Out-Null
$dependencyZip = @(Get-ChildItem $release -Filter '*-dependencies.zip' -File | Select-Object -First 1)
$dependencies = @()
if ($dependencyZip.Count -eq 1) {
    $target = Join-Path $env:RUNNER_TEMP 'tglite-package-dependencies'
    Expand-Archive -LiteralPath $dependencyZip[0].FullName -DestinationPath $target -Force
    $dependencies = @(Get-ChildItem $target -File | Select-Object -ExpandProperty FullName)
}

if ($dependencies.Count -gt 0) {
    Add-AppxPackage -Path $bundle[0].FullName -DependencyPath $dependencies -ErrorAction Stop
}
else {
    Add-AppxPackage -Path $bundle[0].FullName -ErrorAction Stop
}

$app = Get-AppxPackage -Name 'HSOS6Miyabi.TGLite' | Select-Object -First 1
if ($null -eq $app) { throw 'Windows failed to register the installed TGLite application.' }
if ($app.Publisher -cne $env:TGLITE_CERT_SUBJECT) { throw 'Installed package publisher differs from PFX.' }
if ($app.Version.ToString() -ne $env:TGLITE_PACKAGE_VERSION) { throw 'Installed package version differs from build version.' }
Write-Host 'PASS Windows MSIXBundle installation and package registration'

$exe = Join-Path $app.InstallLocation 'Telegram.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw 'Windows package does not contain Telegram.exe.' }
$launch = Start-Process -FilePath $exe -PassThru -ErrorAction Stop
Start-Sleep -Seconds 12
$started = @(Get-Process -Name 'Telegram' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "$($app.InstallLocation)*" })
if ($started.Count -eq 0) { throw 'TGLite process did not remain running after launch.' }
Write-Host 'PASS Windows packaged application launch'

$result = [ordered]@{
    automated = [ordered]@{
        source_validation = 'passed'
        csharp_and_xaml_syntax = 'passed'
        tdlib_test_dc_authorization = 'passed'
        tdlib_test_dc_saved_messages = 'passed'
        signed_msixbundle = 'passed'
        windows_installation = 'passed'
        windows_launch = 'passed'
    }
    requires_manual_testing = @(
        'Windows interface navigation and appearance',
        'Production Telegram account login and two-factor authentication',
        'Real account message synchronization and media transfers',
        'Voice calls, video calls and device permissions',
        'Advertising and Premium display during extended use'
    )
}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $release 'TEST-RESULTS.json') -Encoding utf8

$metadataPath = Join-Path $release 'BUILD-INFO.json'
$metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
$metadata.checks = @($metadata.checks) + @('TDLib test DC authorization and Saved Messages', 'Windows package installation and launch')
$metadata | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $metadataPath -Encoding utf8

$hashes = @(Get-ChildItem -LiteralPath $release -File |
    Where-Object { $_.Name -ne 'SHA256SUMS.txt' } |
    Sort-Object Name |
    ForEach-Object {
        $sha = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$sha  $($_.Name)"
    })
$hashes | Set-Content -LiteralPath (Join-Path $release 'SHA256SUMS.txt') -Encoding ascii

foreach ($process in $started) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
}
Write-Host 'PASS release test results and checksum files'
