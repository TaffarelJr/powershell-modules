#Requires -Version 7.6

<#
.SYNOPSIS
    Builds, stamps, checks and packs one module's release, from the commit
    checked out, without changing the repository.

.DESCRIPTION
    This is everything the draft release does to a module except talk to
    GitHub. In order:

      1. Get-NextVersion works out the version, or checks the one asked for.
         Nothing to release is an error that says how to release anyway.
      2. Build-Module builds the single-file module into the output folder.
      3. New-ReleaseText writes the release notes and the CHANGELOG.md, and
         the CHANGELOG.md goes into the built folder.
      4. Set-ManifestRelease writes the version and the release page link
         into the built manifest.
      5. Test-BuiltModule checks the folder.
      6. Compress-PSResource packs the folder into the .nupkg.

    The repository is never written to: the version and the changelog exist
    only in the output folder and in the package.

.PARAMETER Module
    The module's folder name under src/, such as TaffarelJr.Tally.

.PARAMETER Repository
    The GitHub repository as owner/name, used for the release page link
    written into the manifest.

.PARAMETER OutputPath
    The folder to work in and write the package and the release text to.

.PARAMETER Version
    The version to release, MAJOR.MINOR.PATCH. Without it the version is
    worked out from the commits.

.PARAMETER RepositoryPath
    The repository to build from. Defaults to the one holding this script.

.PARAMETER Cliff
    The git-cliff executable. Defaults to the one on the path.

.OUTPUTS
    A PSCustomObject with Module, Version, Tag, Commit (the commit built),
    Package (the .nupkg path), NotesPath and Folder (the built module).

.EXAMPLE
    ./build/New-ModulePackage.ps1 -Module TaffarelJr.Tally -Repository owner/repo -OutputPath ./out/release

    Packs the next release of the Tally module.
#>
using namespace System.IO

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Module,

    [Parameter(Mandatory)]
    [string]$Repository,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [string]$Version,

    [string]$RepositoryPath = (Join-Path -Path $PSScriptRoot -ChildPath '..'),

    [string]$Cliff = 'git-cliff'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Repository -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
    throw "The repository '$Repository' is not owner/name."
}

$repositoryRoot = [Path]::GetFullPath($RepositoryPath)
$sourceRoot = Join-Path -Path $repositoryRoot -ChildPath 'src'
$here = $PSScriptRoot
$nextArguments = @{
    Module         = $Module
    RepositoryPath = $repositoryRoot
    Cliff          = $Cliff
}
if ($Version) {
    $nextArguments.Version = $Version
}

$plan = & (Join-Path $here 'Get-NextVersion.ps1') @nextArguments
if (-not $plan.Next) {
    throw "There is nothing to release for ${Module}: no commit since $($plan.Last) " +
    'changes what a user sees. Pass -Version to release it anyway.'
}

$work = [Path]::GetFullPath($OutputPath)
$built = & (Join-Path $here 'Build-Module.ps1') -Name $Module -SourceRoot $sourceRoot `
    -OutputPath (Join-Path $work 'built') -PassThru
$text = & (Join-Path $here 'New-ReleaseText.ps1') -Module $Module -Version $plan.Next `
    -OutputPath (Join-Path $work 'text') -RepositoryPath $repositoryRoot -Cliff $Cliff
Copy-Item -LiteralPath $text.ChangelogPath -Destination (Join-Path $built.Path 'CHANGELOG.md')

$page = "https://github.com/$Repository/releases/tag/$($plan.Tag)"
$manifest = Join-Path $built.Path "$Module.psd1"
& (Join-Path $here 'Set-ManifestRelease.ps1') -Path $manifest -Version $plan.Next `
    -ReleaseNotesUrl $page
$null = & (Join-Path $here 'Test-BuiltModule.ps1') -Path $built.Path -SourceRoot $sourceRoot

Import-Module Microsoft.PowerShell.PSResourceGet
$packages = Join-Path $work 'package'
$null = New-Item -ItemType Directory -Path $packages -Force
$package = Compress-PSResource -Path $built.Path -DestinationPath $packages -PassThru
$commit = (& git -C $repositoryRoot rev-parse HEAD).Trim()

return [PSCustomObject]@{
    Module    = $Module
    Version   = $plan.Next
    Tag       = $plan.Tag
    Commit    = $commit
    Package   = $package.FullName
    NotesPath = $text.NotesPath
    Folder    = $built.Path
}
