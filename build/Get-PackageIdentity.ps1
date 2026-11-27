#Requires -Version 7.6

<#
.SYNOPSIS
    Reads what a .nupkg says it is: its id and version from its metadata, and
    the version from the module manifest inside it.

.DESCRIPTION
    A package is a zip. Its .nuspec names the package and its version, and the
    module's own manifest, inside it, names the version the module reports.
    A release is only sound when they agree with each other and with the tag,
    so this reads them without installing anything or running anything in the
    package.

    A file that is not a .nupkg, is not a zip, or holds no .nuspec or no
    manifest is refused.

.PARAMETER Path
    The .nupkg to read.

.OUTPUTS
    A PSCustomObject with Id, Version (from the .nuspec) and ManifestVersion
    (from the module manifest inside the package).

.EXAMPLE
    ./build/Get-PackageIdentity.ps1 -Path ./out/package/TaffarelJr.Tally.0.2.0.nupkg

    Returns the id and the versions the package declares.
#>
using namespace System.IO
using namespace System.IO.Compression

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-EntryText {
    <#
    .SYNOPSIS
        Returns the text of one zip entry.
    #>
    param(
        [Parameter(Mandatory)]
        [ZipArchiveEntry]$Entry
    )

    $reader = [StreamReader]::new($Entry.Open())
    try {
        return $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }
}

$full = [Path]::GetFullPath($Path)
if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    throw "There is no package at '$full'."
}

if ([Path]::GetExtension($full) -cne '.nupkg') {
    throw "'$full' is not a .nupkg file."
}

try {
    $zip = [ZipFile]::OpenRead($full)
}
catch {
    throw "'$full' is not a package: it is not a zip file."
}

try {
    $rootEntries = @($zip.Entries | Where-Object { $_.FullName -notlike '*/*' })
    $nuspec = @($rootEntries | Where-Object { $_.FullName -like '*.nuspec' })
    if ($nuspec.Count -ne 1) {
        throw "'$full' is not a package: it holds $($nuspec.Count) .nuspec files at its root."
    }

    $metadata = ([xml](Read-EntryText -Entry $nuspec[0])).package.metadata
    $id = [string]$metadata.id
    $manifestEntry = @($zip.Entries | Where-Object { $_.FullName -ceq "$id.psd1" })
    if ($manifestEntry.Count -ne 1) {
        throw "'$full' is not a package of a module: it holds no $id.psd1."
    }

    $name = 'identity-' + [guid]::NewGuid().ToString('N') + '.psd1'
    $manifestPath = Join-Path -Path ([Path]::GetTempPath()) -ChildPath $name
    try {
        [File]::WriteAllText($manifestPath, (Read-EntryText -Entry $manifestEntry[0]))
        $data = Import-PowerShellDataFile -LiteralPath $manifestPath
        $manifestVersion = [string]$data.ModuleVersion
    }
    finally {
        Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue
    }

    return [PSCustomObject]@{
        Id              = $id
        Version         = [string]$metadata.version
        ManifestVersion = $manifestVersion
    }
}
finally {
    $zip.Dispose()
}
