#Requires -Version 7.6

<#
.SYNOPSIS
    Returns a module's changelog, every release in the Keep a Changelog
    layout, newest first.

.DESCRIPTION
    A release is a tag <Name>/vX.Y.Z, such as Tally/v0.2.0. The changelog is built one release
    at a time: each release is the range of commits from the release before it
    (or from the first commit, for the first) to its own tag, rendered through
    git-cliff with the rules in .github/cliff.toml and then only the commits
    that touch the module's folder.

    The range is given to git-cliff explicitly. Asking it for the whole
    history by tag does not work here: it recognises a tag only on a commit
    that touches the module's path, so a release tagged on a commit that does
    not (a release made after a change to another module, say) is left out,
    and its commits are shown as unreleased. Nothing after the last release is
    shown, so there is no Unreleased section.

    -NextVersion adds the release that is about to be made, from the commits
    since the last tag up to HEAD, as the newest entry. A release with no
    commit that counts says "No user-facing changes." The version must be
    higher than the last release, not already a tag, and three numbers.

    The result is LF text with one final newline.

.PARAMETER Module
    The module's name, such as Tally. The folder under src/ is TaffarelJr.Tally,
    and either spelling is accepted.

.PARAMETER NextVersion
    The version about to be released, MAJOR.MINOR.PATCH.

.PARAMETER RepositoryPath
    The repository to read. Defaults to the one holding this script.

.PARAMETER Cliff
    The git-cliff executable. Defaults to the one on the path.

.PARAMETER Config
    The git-cliff configuration. Defaults to .github/cliff.toml in the
    repository.

.OUTPUTS
    The changelog text.

.EXAMPLE
    ./build/Get-ModuleChangelog.ps1 -Module Tally -NextVersion 0.2.0

    The changelog of Tally as it will be once 0.2.0 is released.
#>
using namespace System.IO

[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Module,

    [string]$NextVersion,

    [string]$RepositoryPath = (Join-Path -Path $PSScriptRoot -ChildPath '..'),

    [string]$Cliff = 'git-cliff',

    [string]$Config
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'ReleaseName.ps1')

function Get-Release {
    <#
    .SYNOPSIS
        Returns a module's released versions reachable from HEAD, oldest
        first.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Repository,

        [Parameter(Mandatory)]
        [string]$Module
    )

    $glob = Get-ReleaseTagGlob -Module $Module
    $tags = @(& git -C $Repository tag --list $glob --merged HEAD)
    @($tags |
            ForEach-Object { ConvertFrom-ReleaseTag -Tag $_ } |
            Where-Object { $_ -and $_.Module -ceq $Module } |
            ForEach-Object Version |
            Sort-Object { [version]$_ })
}

function Get-ReleaseSection {
    <#
    .SYNOPSIS
        Returns one release's section of the changelog, for the commits in a
        range, as git-cliff renders it.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Cliff,

        [Parameter(Mandatory)]
        [string]$Config,

        [Parameter(Mandatory)]
        [string]$Repository,

        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$Range
    )

    $pattern = Get-ReleaseTagRegex -Module $Module
    $tag = Get-ReleaseTag -Module $Module -Version $Version
    $lines = & $Cliff --config $Config --repository $Repository `
        --include-path "src/$Module/**" --tag-pattern $pattern `
        --tag $tag --strip header $Range 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "git-cliff failed for '$Module' $Version (exit $LASTEXITCODE)."
    }

    $text = (@($lines) -join "`n").Trim()
    if ($text -notmatch '(?m)^### ') {
        $date = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
        return "## [$Version] - $date`n`nNo user-facing changes."
    }

    return $text
}

function Get-FirstCommit {
    <#
    .SYNOPSIS
        Returns the SHA of the first commit reachable from HEAD.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Repository
    )

    @(& git -C $Repository rev-list --max-parents=0 HEAD) | Select-Object -Last 1
}

$repository = [Path]::GetFullPath($RepositoryPath)
$sourceRoot = Join-Path -Path $repository -ChildPath 'src'
$Module = Resolve-ModuleName -Name $Module -SourceRoot $sourceRoot
if (-not $Config) {
    $Config = Join-Path -Path $repository -ChildPath '.github' -AdditionalChildPath 'cliff.toml'
}

if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) {
    throw "There is no git-cliff configuration at '$Config'; without one git-cliff " +
    'silently applies its own default rules.'
}

$releases = @(Get-Release -Repository $repository -Module $Module)
if ($NextVersion) {
    if ($NextVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "Version '$NextVersion' is not MAJOR.MINOR.PATCH, three numbers such as 0.2.0."
    }

    if ($releases.Count -gt 0 -and [version]$NextVersion -le [version]$releases[-1]) {
        $last = $releases[-1]
        throw "Version $NextVersion is not higher than the last release of $Module, $last."
    }
}

if ($releases.Count -eq 0 -and -not $NextVersion) {
    throw "$Module has no release yet, so it has no changelog."
}

$first = Get-FirstCommit -Repository $repository
$steps = [System.Collections.Generic.List[object]]::new()
$previous = $first
foreach ($version in $releases) {
    $release = Get-ReleaseTag -Module $Module -Version $version
    $steps.Add([PSCustomObject]@{ Version = $version; Range = "$previous..$release" })
    $previous = $release
}

if ($NextVersion) {
    $steps.Add([PSCustomObject]@{ Version = $NextVersion; Range = "$previous..HEAD" })
}

$sections = @($steps | ForEach-Object {
        Get-ReleaseSection -Cliff $Cliff -Config $Config -Repository $repository `
            -Module $Module -Version $_.Version -Range $_.Range
    })
[array]::Reverse($sections)

$header = @(
    '# Changelog'
    ''
    'All notable changes to this module are documented in this file.'
    ''
    'The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),'
    'and this module adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).'
) -join "`n"

return $header + "`n`n" + ($sections -join "`n`n") + "`n"
