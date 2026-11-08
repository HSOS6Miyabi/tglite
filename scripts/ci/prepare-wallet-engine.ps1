param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$version = '0.0.7'
$filename = "wallet-engine-$version-x86_64-pc-windows-msvc.zip"
$expectedHash = '7782b1db3bb9a96c30cfb7cc2d63a56fcaee8c82f0e732d24a180582a1a9fd51'
$url = "https://github.com/i582/wallet-engine/releases/download/v$version/$filename"

$folder = Join-Path $env:RUNNER_TEMP 'tglite-wallet-engine'
$zip = Join-Path $folder $filename
$expanded = Join-Path $folder 'expanded'
$targetFolder = Join-Path $PWD 'Libraries/wallet-engine/x64'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        Invoke-WebRequest -Uri $url -OutFile $zip -MaximumRedirection 10 -TimeoutSec 120 -ErrorAction Stop
        break
    }
    catch {
        if ($attempt -eq 3) { throw }
        Start-Sleep -Seconds ($attempt * 5)
    }
}

$actualHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -cne $expectedHash) {
    throw 'Wallet Engine archive SHA-256 does not match the pinned upstream release.'
}

Expand-Archive -LiteralPath $zip -DestinationPath $expanded -Force
$dllFiles = @(Get-ChildItem -LiteralPath $expanded -Recurse -File -Filter 'wallet_engine.dll')
if ($dllFiles.Count -ne 1) {
    throw "Expected a single wallet_engine.dll in the verified archive; found $($dllFiles.Count)."
}

$destination = Join-Path $targetFolder 'wallet_engine.dll'
Copy-Item -LiteralPath $dllFiles[0].FullName -Destination $destination -Force

$source = Get-Content -LiteralPath 'Telegram/Services/Wallet/Generated/wallet_engine.cs' -Raw
$exports = @([regex]::Matches($source, '\bffi_wallet_engine_[A-Za-z0-9_]+(?=\s*\()') |
    ForEach-Object { $_.Value } | Sort-Object -Unique)
if ($exports.Count -lt 20) {
    throw 'The generated C# wallet bindings contain unexpectedly few native exports.'
}

$nativeLibrary = [System.Runtime.InteropServices.NativeLibrary]::Load($destination)
try {
    $missing = @()
    foreach ($export in $exports) {
        $address = [IntPtr]::Zero
        if (-not [System.Runtime.InteropServices.NativeLibrary]::TryGetExport(
            $nativeLibrary, $export, [ref]$address)) {
            $missing += $export
        }
    }
    if ($missing.Count -gt 0) {
        throw "Wallet Engine is incompatible with the generated C# bindings. Missing exports: $($missing -join ', ')"
    }
}
finally {
    [System.Runtime.InteropServices.NativeLibrary]::Free($nativeLibrary)
}

Write-Host "PASS Wallet Engine $version, verified ZIP SHA-256 and $($exports.Count) native exports."
