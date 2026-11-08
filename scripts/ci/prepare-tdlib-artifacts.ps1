param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath '.').Path
$source = Join-Path $root 'Libraries/tdlib/td/generate/scheme/td_api.tl'
$destination = Join-Path $root 'Libraries/tdjson/td_api.tl'
$native = Join-Path $root 'Libraries/tdjson/x64-windows'

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw 'The TDLib source submodule does not contain td_api.tl.'
}

$sourceSha = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
if ((-not (Test-Path -LiteralPath $destination -PathType Leaf)) -or
    ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $sourceSha)) {
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

if ((Get-Item -LiteralPath $destination).Length -lt 4096) {
    throw 'The exported TDLib schema is unexpectedly small.'
}
Write-Host 'PASS TDLib API schema is present and matches the pinned source.'

if (Test-Path -LiteralPath $native -PathType Container) {
    $required = @('tdjson.dll', 'tdjson.pdb', 'libcrypto-3-x64.dll', 'libssl-3-x64.dll', 'zlib1.dll')
    foreach ($file in $required) {
        $path = Join-Path $native $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "The TDLib native output is incomplete: $file"
        }
    }
    Write-Host 'PASS TDLib native output and dependencies.'
}
