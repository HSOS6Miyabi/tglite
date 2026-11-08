param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $env:TGLITE_CERT_THUMBPRINT) {
    throw 'The signing certificate has not been imported.'
}
$exe = @(Get-ChildItem -LiteralPath 'scripts/TdlibSmoke/bin/Release' -Filter 'TdlibSmoke.exe' -Recurse -File)
if ($exe.Count -ne 1) {
    throw "Expected exactly one Windows signing test executable. Found $($exe.Count)."
}
$sdkBin = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$tool = @(Get-ChildItem -LiteralPath $sdkBin -Filter 'signtool.exe' -Recurse -File |
    Where-Object { $_.DirectoryName -match '[\\/]x64$' } |
    Sort-Object FullName -Descending | Select-Object -First 1)
if ($tool.Count -ne 1) {
    throw 'The Windows SDK code-signing tool is unavailable.'
}
& $tool[0].FullName sign /v /fd SHA256 /sha1 $env:TGLITE_CERT_THUMBPRINT /s My $exe[0].FullName
if ($LASTEXITCODE -ne 0) { throw 'The configured PFX could not sign a Windows executable.' }
& $tool[0].FullName verify /pa /v $exe[0].FullName
if ($LASTEXITCODE -ne 0) { throw 'The signed Windows executable failed verification.' }
Write-Host 'PASS PFX signature and certification chain in the Windows build environment.'
