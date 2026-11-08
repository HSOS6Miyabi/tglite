param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$source = Join-Path $env:VCPKG_ROOT 'scripts/cmake/vcpkg_from_github.cmake'
if (-not (Test-Path -LiteralPath $source)) {
    throw 'vcpkg_from_github.cmake is missing from the configured vcpkg installation.'
}

$content = Get-Content -LiteralPath $source -Raw
$marker = '    # Try to download the file information from github'
$needle = '        URLS "${download_url}"'
if ($content.IndexOf($marker) -lt 0 -or
    $content.IndexOf($marker) -ne $content.LastIndexOf($marker) -or
    $content.IndexOf($needle) -lt 0 -or
    $content.IndexOf($needle) -ne $content.LastIndexOf($needle)) {
    throw 'The installed vcpkg source helper has an unexpected structure.'
}

$insert = @'
    set(tglite_source_urls "${download_url}")
    if(NOT DEFINED arg_GITHUB_HOST AND NOT DEFINED arg_AUTHORIZATION_TOKEN AND NOT arg_USE_TARBALL_API)
        list(PREPEND tglite_source_urls "https://codeload.github.com/${org_name}/${repo_name}/tar.gz/${ref_to_use}")
    endif()

'@
$content = $content.Replace($marker, $insert + $marker)
$content = $content.Replace($needle, '        URLS ${tglite_source_urls}')
Set-Content -LiteralPath $source -Value $content -Encoding utf8
Write-Host 'Configured alternative GitHub archive URLs; SHA512 verification is unchanged.'
