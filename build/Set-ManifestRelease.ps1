#Requires -Version 7.6

<#
.SYNOPSIS
    Writes a release's version and release notes link into a module manifest.

.DESCRIPTION
    The source manifest keeps a placeholder version, and nothing about a
    release is committed to the repository. This is run on a copy of the
    manifest in the build output: it replaces the ModuleVersion line and the
    ReleaseNotes line and nothing else, so every other byte of the manifest
    stays as it was, including its CRLF line endings.

    The manifest must have exactly one ModuleVersion line and one
    ReleaseNotes line, each a single quoted string. Anything else is refused
    and the file is left as it was. The result is checked by reading the
    manifest back.

.PARAMETER Path
    The manifest to change.

.PARAMETER Version
    The release version, MAJOR.MINOR.PATCH, three numbers with no label.

.PARAMETER ReleaseNotesUrl
    The https link the Gallery shows as the module's release notes.

.EXAMPLE
    ./build/Set-ManifestRelease.ps1 -Path ./out/TaffarelJr.Tally/TaffarelJr.Tally.psd1 -Version 0.2.0 -ReleaseNotesUrl https://github.com/owner/repo/releases/tag/Tally/v0.2.0

    Stamps version 0.2.0 and its release page into the built manifest.
#>
using namespace System.IO
using namespace System.Text

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$ReleaseNotesUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version '$Version' is not MAJOR.MINOR.PATCH, three numbers such as 0.2.0."
}

if ($ReleaseNotesUrl -notmatch '^https://[^\s''"]+$') {
    throw "The release notes link '$ReleaseNotesUrl' is not an https link."
}

$full = [Path]::GetFullPath($Path)
if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    throw "There is no manifest at '$full'."
}

$text = [File]::ReadAllText($full)
$versionLine = '(?m)^(\s*ModuleVersion\s*=\s*)''[^'']*''(\s*)$'
$notesLine = '(?m)^(\s*ReleaseNotes\s*=\s*)''[^'']*''(\s*)$'
$versions = [regex]::Matches($text, $versionLine).Count
$notes = [regex]::Matches($text, $notesLine).Count
if ($versions -ne 1) {
    throw "'$full' has $versions ModuleVersion lines; it must have exactly one."
}

if ($notes -ne 1) {
    throw "'$full' has $notes ReleaseNotes lines; it must have exactly one."
}

$text = [regex]::Replace($text, $versionLine, "`${1}'$Version'`${2}")
$text = [regex]::Replace($text, $notesLine, "`${1}'$ReleaseNotesUrl'`${2}")
[File]::WriteAllText($full, $text, [UTF8Encoding]::new($false))

$data = Import-PowerShellDataFile -LiteralPath $full
$written = $data.PrivateData.PSData.ReleaseNotes
if ($data.ModuleVersion -cne $Version -or $written -cne $ReleaseNotesUrl) {
    throw "'$full' does not say what was written to it."
}
