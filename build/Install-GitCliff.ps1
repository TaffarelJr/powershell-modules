#Requires -Version 7.6

<#
.SYNOPSIS
    Downloads one pinned release of git-cliff into a folder, checks it against
    a checksum, and returns the path of the executable.

.DESCRIPTION
    The release workflow runs git-cliff, and what it runs must be what was
    reviewed. The version is named, the checksum of the archive for the
    platform is named with it, and an archive that does not match is refused
    before anything is unpacked.

    The archive comes from the project's own GitHub releases, through gh
    when it is signed in and plain HTTPS otherwise.

.PARAMETER Version
    The git-cliff version, such as 2.14.2.

.PARAMETER Sha256
    The SHA-256 of the archive for this platform, as GitHub lists it for the
    release asset.

.PARAMETER Destination
    The folder to unpack into. Created if missing.

.PARAMETER Platform
    The release's platform name. Defaults to the one this process runs on:
    x86_64-unknown-linux-gnu on Linux and x86_64-pc-windows-msvc on Windows.

.OUTPUTS
    The path of the git-cliff executable.

.EXAMPLE
    ./build/Install-GitCliff.ps1 -Version 2.14.2 -Sha256 24f397c733add5390fdceee3a2088588ab0d5f944ce00d34cb7029b888cf2db4 -Destination ./tools

    Installs git-cliff 2.14.2 for Linux into ./tools and returns its path.
#>
using namespace System.IO
using namespace System.Net.Http

[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$Sha256,

    [Parameter(Mandatory)]
    [string]$Destination,

    [string]$Platform
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version '$Version' is not MAJOR.MINOR.PATCH."
}

if ($Sha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'The checksum is not a SHA-256: 64 hexadecimal digits.'
}

if (-not $Platform) {
    $Platform = $IsWindows ? 'x86_64-pc-windows-msvc' : 'x86_64-unknown-linux-gnu'
}

$isZip = $Platform -like '*windows*'
$asset = "git-cliff-$Version-$Platform" + ($isZip ? '.zip' : '.tar.gz')
$name = 'git-cliff-' + [guid]::NewGuid().ToString('N')
$work = Join-Path -Path ([Path]::GetTempPath()) -ChildPath $name
$null = New-Item -ItemType Directory -Path $work
try {
    $archive = Join-Path $work $asset
    $url = "https://github.com/orhun/git-cliff/releases/download/v$Version/$asset"
    Invoke-WebRequest -Uri $url -OutFile $archive -ErrorAction Stop

    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    if ($actual -ne $Sha256.ToUpperInvariant()) {
        $want = $Sha256.ToLowerInvariant()
        $got = $actual.ToLowerInvariant()
        throw "The checksum of $asset does not match: expected $want, got $got."
    }

    $null = New-Item -ItemType Directory -Path $Destination -Force
    if ($isZip) {
        Expand-Archive -LiteralPath $archive -DestinationPath $Destination -Force
    }
    else {
        & tar -xzf $archive -C $Destination
        if ($LASTEXITCODE -ne 0) {
            throw "tar could not unpack $asset (exit $LASTEXITCODE)."
        }
    }

    $name = $isZip ? 'git-cliff.exe' : 'git-cliff'
    $found = @(Get-ChildItem -LiteralPath $Destination -Recurse -File -Filter $name)
    if ($found.Count -eq 0) {
        throw "$asset holds no $name."
    }

    return $found[0].FullName
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
