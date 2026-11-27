#Requires -Version 7.6

<#
.SYNOPSIS
    Writes the text of one module release: the notes for the release page and
    the CHANGELOG.md that ships in the package.

.DESCRIPTION
    Both come from Get-ModuleChangelog, so they are built from the same
    commits as the version and cannot disagree with it or with each other.

    notes.md holds this release only: a dated heading for the version and its
    changes grouped as Added, Changed, Fixed and Removed, a breaking change
    marked and listed with the rest. A release with no commit that counts
    says so instead of being empty. It is the body of the draft release, and
    can be edited before the release is published.

    CHANGELOG.md holds every release of the module in the Keep a Changelog
    layout, newest first, the new one included. It is generated, never
    committed to the repository, and ships inside the package so it is there
    offline.

    The version is checked the same way Get-NextVersion checks one that was
    asked for: three numbers, higher than the last release, not already a
    tag. Both files are LF text with a final newline and no byte order mark.

.PARAMETER Module
    The module's folder name under src/, such as TaffarelJr.Tally.

.PARAMETER Version
    The version being released, MAJOR.MINOR.PATCH, with no label or v.

.PARAMETER OutputPath
    The folder to write notes.md and CHANGELOG.md into. Created if missing.

.PARAMETER RepositoryPath
    The repository to read. Defaults to the one holding this script.

.PARAMETER Cliff
    The git-cliff executable. Defaults to the one on the path.

.PARAMETER Config
    The git-cliff configuration. Defaults to .github/cliff.toml in the
    repository.

.OUTPUTS
    A PSCustomObject with NotesPath and ChangelogPath.

.EXAMPLE
    ./build/New-ReleaseText.ps1 -Module TaffarelJr.Tally -Version 0.2.0 -OutputPath ./out/text

    Writes out/text/notes.md and out/text/CHANGELOG.md for Tally 0.2.0.
#>
using namespace System.IO
using namespace System.Text

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Module,

    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [string]$RepositoryPath = (Join-Path -Path $PSScriptRoot -ChildPath '..'),

    [string]$Cliff = 'git-cliff',

    [string]$Config
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NewestSection {
    <#
    .SYNOPSIS
        Returns the first release section of a changelog: the newest.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Changelog
    )

    $parts = [regex]::Split($Changelog, '(?m)^(?=## \[)')
    return $parts[1].Trim()
}

function Write-LfFile {
    <#
    .SYNOPSIS
        Writes text as UTF-8 without a byte order mark, with LF line endings
        and one final newline.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Text
    )

    $body = ($Text -replace "`r`n", "`n").TrimEnd("`n") + "`n"
    [File]::WriteAllText($Path, $body, [UTF8Encoding]::new($false))
}

$repository = [Path]::GetFullPath($RepositoryPath)
if (-not $Config) {
    $Config = Join-Path -Path $repository -ChildPath '.github' -AdditionalChildPath 'cliff.toml'
}

if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) {
    throw "There is no git-cliff configuration at '$Config'; without one git-cliff " +
    'silently applies its own default rules.'
}

$null = & (Join-Path -Path $PSScriptRoot -ChildPath 'Get-NextVersion.ps1') `
    -Module $Module -Version $Version -RepositoryPath $repository -Cliff $Cliff -Config $Config

$changelog = & (Join-Path -Path $PSScriptRoot -ChildPath 'Get-ModuleChangelog.ps1') `
    -Module $Module -NextVersion $Version -RepositoryPath $repository -Cliff $Cliff -Config $Config

$null = New-Item -ItemType Directory -Path $OutputPath -Force
$notesPath = Join-Path -Path $OutputPath -ChildPath 'notes.md'
$changelogPath = Join-Path -Path $OutputPath -ChildPath 'CHANGELOG.md'
Write-LfFile -Path $notesPath -Text (Get-NewestSection -Changelog $changelog)
Write-LfFile -Path $changelogPath -Text $changelog

return [PSCustomObject]@{
    NotesPath     = $notesPath
    ChangelogPath = $changelogPath
}
