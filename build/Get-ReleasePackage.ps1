#Requires -Version 7.6

<#
.SYNOPSIS
    Downloads the package attached to a release and checks it is the package
    of that release.

.DESCRIPTION
    The publish step never rebuilds: it publishes the package the draft
    release carries, so what reaches a feed is what was packed and checked.
    The tag names the module and the version, <Name>/vX.Y.Z, such as
    Tally/v0.2.0. The release must hold exactly one .nupkg, and that package must be the
    module's, at that version, with the same version in its manifest. The
    destination is emptied of packages first so an old one is never mistaken
    for this release's.

    -Sha256 pins the package to a checksum known beforehand, for a caller that
    has one. The checksum of what was downloaded is always returned.

.PARAMETER Tag
    The release tag, <Name>/vX.Y.Z.

.PARAMETER Repository
    The GitHub repository as owner/name.

.PARAMETER Destination
    The folder to download into. Created if missing.

.PARAMETER Sha256
    The checksum the package must have.

.OUTPUTS
    A PSCustomObject with Module, Version, Tag, Path and Sha256.

.EXAMPLE
    ./build/Get-ReleasePackage.ps1 -Tag Tally/v0.2.0 -Repository owner/repo -Destination ./out/package

    Downloads and checks the package of the Tally 0.2.0 release.
#>
using namespace System.IO

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Tag,

    [Parameter(Mandatory)]
    [string]$Repository,

    [Parameter(Mandatory)]
    [string]$Destination,

    [string]$Sha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'ReleaseName.ps1')

$parsed = ConvertFrom-ReleaseTag -Tag $Tag
if (-not $parsed) {
    throw "The tag '$Tag' is not <Name>/vX.Y.Z, such as Tally/v0.2.0."
}

$module = $parsed.Module
$version = $parsed.Version
if ($Repository -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
    throw "The repository '$Repository' is not owner/name."
}

$folder = [Path]::GetFullPath($Destination)
$null = New-Item -ItemType Directory -Path $folder -Force
Get-ChildItem -LiteralPath $folder -Filter '*.nupkg' -File | Remove-Item -Force

gh release download $Tag --repo $Repository --pattern '*.nupkg' --dir $folder
if ($LASTEXITCODE -ne 0) {
    throw "gh could not download the package of release $Tag (exit $LASTEXITCODE)."
}

$packages = @(Get-ChildItem -LiteralPath $folder -Filter '*.nupkg' -File)
if ($packages.Count -ne 1) {
    throw "Release $Tag must carry exactly one .nupkg; it carries $($packages.Count)."
}

$path = $packages[0].FullName
$hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Sha256 -and $hash -ne $Sha256.ToLowerInvariant()) {
    $expected = $Sha256.ToLowerInvariant()
    throw "The checksum of the package is $hash, not the $expected that was expected."
}

$identity = & (Join-Path -Path $PSScriptRoot -ChildPath 'Get-PackageIdentity.ps1') -Path $path
if ($identity.Id -cne $module) {
    throw "Release $Tag names $module but its package is $($identity.Id)."
}

if ($identity.Version -cne $version -or $identity.ManifestVersion -cne $version) {
    throw "Release $Tag is $version but its package says $($identity.Version) " +
    "and its manifest says $($identity.ManifestVersion)."
}

return [PSCustomObject]@{
    Module  = $module
    Version = $version
    Tag     = $Tag
    Path    = $path
    Sha256  = $hash
}
