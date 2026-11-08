param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$installer = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer'
$vswhere = Join-Path $installer 'vswhere.exe'
$vs = & $vswhere -latest -prerelease -products '*' -requires Microsoft.Component.MSBuild -property installationPath
if (-not $vs) { throw 'Visual Studio with MSBuild was not found.' }
$msbuild = Join-Path $vs 'MSBuild\Current\Bin\amd64\MSBuild.exe'

if (-not $env:TGLITE_CERT_SUBJECT -or -not $env:TGLITE_CERT_THUMBPRINT -or -not $env:TGLITE_PACKAGE_VERSION) {
    throw 'Package signing configuration is incomplete.'
}
$certificate = Get-ChildItem 'Cert:\CurrentUser\My' |
    Where-Object { $_.Thumbprint -eq $env:TGLITE_CERT_THUMBPRINT -and $_.HasPrivateKey } |
    Select-Object -First 1
if ($null -eq $certificate) {
    throw 'The signing certificate cannot be found in the current user certificate store.'
}
if ($certificate.Subject -cne $env:TGLITE_CERT_SUBJECT) {
    throw 'Certificate subject and configured package publisher differ.'
}

$project = Join-Path $PWD 'Telegram/Telegram.WinUI.csproj'
$arguments = @(
    $project,
    '-nologo',
    '-p:Configuration=Release',
    '-p:Platform=x64',
    '-p:WinUIIdentity=Bundle',
    '-p:WinUIPackageIdentity=HSOS6Miyabi.TGLite',
    '-p:WinUIPackageDisplayName=TGLite',
    "-p:WinUIPackageVersion=$env:TGLITE_PACKAGE_VERSION",
    "-p:PackageCertificateThumbprint=$env:TGLITE_CERT_THUMBPRINT",
    '-getProperty:TGLitePackagePublisher'
)
$resolved = (& $msbuild @arguments | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'MSBuild failed to evaluate the TGLite package publisher.'
}
if ($resolved -cne $env:TGLITE_CERT_SUBJECT) {
    throw "The Windows package publisher differs from the configured signing certificate."
}
if (-not (Test-Path -LiteralPath 'Telegram/Constants.Secret.cs')) {
    throw 'Telegram API configuration is missing.'
}

Write-Host 'MSBuild package identity and signing publisher verified.'
