#Requires -Version 7.6

<#
.SYNOPSIS
    Writes a module's changelog page into a clone of the repository's wiki and
    commits it, when it changed.

.DESCRIPTION
    The page is the module's whole changelog, from Get-ModuleChangelog, under
    a heading and a note that it is generated. It is rewritten whole from the
    release tags each time, never edited, so a run that is repeated cannot
    duplicate an entry and a hand edit is overwritten. Only released versions
    are on it: nothing after the last tag is shown.

    The wiki is a separate git repository. This works in a clone of it that
    the caller made and will push, so the script itself holds no credential.
    A change is a new commit, never an amend, made as the GitHub Actions bot.
    A page that did not change makes no commit.

    A module with no release is refused. The wiki's other pages are never
    touched.

.PARAMETER Module
    The module's folder name under src/, such as TaffarelJr.Tally.

.PARAMETER WikiPath
    A clone of the wiki repository.

.PARAMETER RepositoryPath
    The repository holding the module and its tags. Defaults to the one
    holding this script.

.PARAMETER Cliff
    The git-cliff executable. Defaults to the one on the path.

.PARAMETER Config
    The git-cliff configuration. Defaults to .github/cliff.toml in the
    repository.

.OUTPUTS
    A PSCustomObject with Page (the file name), Version (the newest release
    on it) and Changed (whether a commit was made).

.EXAMPLE
    ./build/Update-ChangelogWiki.ps1 -Module TaffarelJr.Tally -WikiPath ./wiki

    Rewrites the Tally page in ./wiki and commits it if it changed.
#>
using namespace System.IO
using namespace System.Text

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Module,

    [Parameter(Mandatory)]
    [string]$WikiPath,

    [string]$RepositoryPath = (Join-Path -Path $PSScriptRoot -ChildPath '..'),

    [string]$Cliff = 'git-cliff',

    [string]$Config
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PageText {
    <#
    .SYNOPSIS
        Returns the wiki page for a module, from its changelog: a heading, a
        note that it is generated, and the releases without the changelog's
        own header.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Changelog
    )

    $releases = $Changelog.Substring($Changelog.IndexOf('## [')).Trim()
    $head = "# $Module changelog`n`n" +
    "<!-- Generated from the release tags when a release is published. Do not edit. -->`n`n" +
    'All notable changes to this module are documented here, in the format of ' +
    "[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).`n`n"
    return $head + $releases + "`n"
}

$wiki = [Path]::GetFullPath($WikiPath)
& git -C $wiki rev-parse --git-dir *> $null
if ($LASTEXITCODE -ne 0) {
    throw "'$wiki' is not a git repository."
}

$arguments = @{
    Module         = $Module
    RepositoryPath = $RepositoryPath
    Cliff          = $Cliff
}
if ($Config) {
    $arguments.Config = $Config
}

$changelog = & (Join-Path -Path $PSScriptRoot -ChildPath 'Get-ModuleChangelog.ps1') @arguments
$version = [regex]::Match($changelog, '(?m)^## \[(\d+\.\d+\.\d+)\]').Groups[1].Value

$page = "$Module-Changelog.md"
$text = Get-PageText -Module $Module -Changelog $changelog
[File]::WriteAllText((Join-Path -Path $wiki -ChildPath $page), $text, [UTF8Encoding]::new($false))

$identity = @(
    '-c', 'user.name=github-actions[bot]'
    '-c', 'user.email=41898282+github-actions[bot]@users.noreply.github.com'
    '-c', 'core.autocrlf=false'
    '-c', 'core.safecrlf=false'
)
& git -C $wiki @identity add -- $page
$changed = @(& git -C $wiki diff --cached --name-only).Count -gt 0
if ($changed) {
    & git -C $wiki @identity commit -q -m "docs: update the $Module changelog for $version"
    if ($LASTEXITCODE -ne 0) {
        throw "git could not commit the changelog page (exit $LASTEXITCODE)."
    }
}

return [PSCustomObject]@{
    Page    = $page
    Version = $version
    Changed = $changed
}
