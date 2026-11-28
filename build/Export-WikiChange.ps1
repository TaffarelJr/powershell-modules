#Requires -Version 7.6

<#
.SYNOPSIS
    Packs the commit Update-ModuleWiki.ps1 made in a wiki clone into a git
    bundle, so another job can push it.

.DESCRIPTION
    The job that makes the pages runs the released package's code, so it holds
    no credential that can write. It hands the one commit it made to a job that
    runs no package code, as a bundle: data that git reads back and checks, and
    that can carry nothing but commits.

    The clone must be on its branch, with exactly one commit ahead of the
    remote's, and no uncommitted change.

.PARAMETER WikiPath
    The clone of the wiki repository.

.PARAMETER BundlePath
    The bundle file to write.

.PARAMETER Branch
    The wiki's branch. Defaults to master, the only branch GitHub shows.

.OUTPUTS
    The full path of the bundle.

.EXAMPLE
    ./build/Export-WikiChange.ps1 -WikiPath ./wiki -BundlePath ./wiki.bundle

    Writes the commit ahead of origin/master in ./wiki to ./wiki.bundle.
#>
using namespace System.IO

[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [string]$WikiPath,

    [Parameter(Mandatory)]
    [string]$BundlePath,

    [string]$Branch = 'master'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$wiki = [Path]::GetFullPath($WikiPath)
$bundle = [Path]::GetFullPath($BundlePath)
& git -C $wiki rev-parse --git-dir *> $null
if ($LASTEXITCODE -ne 0) {
    throw "'$wiki' is not a git repository."
}

$dirty = @(& git -C $wiki status --porcelain)
if ($dirty.Count -gt 0) {
    throw "The wiki clone at '$wiki' has $($dirty.Count) uncommitted change(s)."
}

$ahead = (& git -C $wiki rev-list --count "origin/$Branch..HEAD")
if ($LASTEXITCODE -ne 0) {
    throw "git could not compare the wiki clone with origin/$Branch (exit $LASTEXITCODE)."
}

if ([int]$ahead -ne 1) {
    throw "The wiki clone is $ahead commit(s) ahead of origin/$Branch; exactly one is expected."
}

$null = New-Item -ItemType Directory -Path (Split-Path -Parent $bundle) -Force
& git -C $wiki bundle create $bundle HEAD "^origin/$Branch" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "git could not write the bundle (exit $LASTEXITCODE)."
}

return $bundle
