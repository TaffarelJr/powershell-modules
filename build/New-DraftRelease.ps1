#Requires -Version 7.6

<#
.SYNOPSIS
    Creates the draft GitHub release for a module version, with its package
    attached, replacing a draft that is already there.

.DESCRIPTION
    A draft has no tag and starts nothing, so a wrong one is deleted and made
    again at no cost. The draft is pinned to the commit that was built, so the
    tag lands on it when the release is published, even if the branch has
    moved on. It is not marked as the latest release, because modules are
    released independently and none is the latest of the repository.

    A tag that already has a published release is refused: a published
    release is never replaced. Everything is checked before anything is
    deleted or created.

.PARAMETER Tag
    The release tag, <Name>/vX.Y.Z, such as Tally/v0.2.0. It is also the title.

.PARAMETER Repository
    The GitHub repository as owner/name.

.PARAMETER NotesPath
    The release notes, a Markdown file.

.PARAMETER Package
    The .nupkg to attach.

.PARAMETER Commit
    The full 40-character SHA of the commit that was built.

.OUTPUTS
    The address of the draft release.

.EXAMPLE
    ./build/New-DraftRelease.ps1 -Tag Tally/v0.2.0 -Repository owner/repo -NotesPath ./out/text/notes.md -Package ./out/package/TaffarelJr.Tally.0.2.0.nupkg -Commit 0123456789abcdef0123456789abcdef01234567

    Drafts the release for Tally 0.2.0.
#>
using namespace System.IO

[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Tag,

    [Parameter(Mandatory)]
    [string]$Repository,

    [Parameter(Mandatory)]
    [string]$NotesPath,

    [Parameter(Mandatory)]
    [string]$Package,

    [Parameter(Mandatory)]
    [string]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'ReleaseName.ps1')

function Invoke-Gh {
    <#
    .SYNOPSIS
        Runs gh and refuses a failure.
    #>
    param(
        [Parameter(Mandatory)]
        [string[]]$Argument
    )

    $output = gh @Argument
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($Argument[0]) $($Argument[1]) failed (exit $LASTEXITCODE)."
    }

    return $output
}

if (-not (ConvertFrom-ReleaseTag -Tag $Tag)) {
    throw "The tag '$Tag' is not <Name>/vX.Y.Z, such as Tally/v0.2.0."
}

if ($Repository -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
    throw "The repository '$Repository' is not owner/name."
}

if ($Commit -notmatch '^[0-9a-f]{40}$') {
    throw "The commit '$Commit' is not a full 40-character SHA."
}

foreach ($file in $NotesPath, $Package) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "There is no file at '$file'."
    }
}

$releases = @((Invoke-Gh -Argument 'release', 'list', '--repo', $Repository, '--limit', '200',
            '--json', 'tagName,isDraft') | ConvertFrom-Json)
$existing = @($releases | Where-Object { $_.tagName -ceq $Tag })
if (@($existing | Where-Object { -not $_.isDraft }).Count -gt 0) {
    throw "The release $Tag is already published, and a published release is never replaced."
}

if ($existing.Count -gt 0) {
    $null = Invoke-Gh -Argument 'release', 'delete', $Tag, '--repo', $Repository, '--yes'
}

$url = Invoke-Gh -Argument 'release', 'create', $Tag, '--repo', $Repository, '--draft',
'--title', $Tag, '--notes-file', $NotesPath, '--target', $Commit, '--latest=false'
$null = Invoke-Gh -Argument 'release', 'upload', $Tag, $Package, '--repo', $Repository, '--clobber'

return @($url)[-1]
