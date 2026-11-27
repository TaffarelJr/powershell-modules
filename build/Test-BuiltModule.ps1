#Requires -Version 7.6

<#
.SYNOPSIS
    Checks a built module folder before it is packed, and refuses it if
    anything is wrong.

.DESCRIPTION
    The package is the folder, whole: nothing is excluded when it is packed.
    So the checks are what a published package must be.

      - the folder holds the module file, the manifest, README.md and
        CHANGELOG.md, and nothing else except a Scripts folder;
      - the module file parses;
      - the manifest passes Test-ModuleManifest, with the source root on
        PSModulePath so required modules resolve;
      - PSScriptAnalyzer finds nothing in the built file, with the default
        rules, retried when the analyzer itself crashes, which it does now
        and then;
      - a fresh process imports the built module, and what it exports is
        exactly what the manifest lists.

    The first problem found is the error. Nothing is changed.

.PARAMETER Path
    The built module folder, such as out/TaffarelJr.Tally.

.PARAMETER SourceRoot
    The folder holding the module folders, put on PSModulePath so a required
    module in this repository resolves. Defaults to src/ beside this
    script's own folder.

.OUTPUTS
    A PSCustomObject with Module, Version and Export (the exported function
    names).

.EXAMPLE
    ./build/Test-BuiltModule.ps1 -Path ./out/TaffarelJr.Tally

    Checks the built Tally module.
#>
using namespace System.IO
using namespace System.Management.Automation.Language

[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Path,

    [string]$SourceRoot = (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'src')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Content {
    <#
    .SYNOPSIS
        Refuses a built folder that lacks a required file or holds one that
        does not belong.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Folder,

        [Parameter(Mandatory)]
        [string]$Module
    )

    foreach ($required in "$Module.psm1", "$Module.psd1", 'README.md', 'CHANGELOG.md') {
        if (-not (Test-Path -LiteralPath (Join-Path $Folder $required) -PathType Leaf)) {
            throw "The built module has no $required."
        }
    }

    $allowed = @("$Module.psm1", "$Module.psd1", 'README.md', 'CHANGELOG.md')
    $files = @(Get-ChildItem -LiteralPath $Folder -Recurse -File)
    foreach ($file in $files) {
        $relative = [Path]::GetRelativePath($Folder, $file.FullName).Replace('\', '/')
        if ($relative -notin $allowed -and -not $relative.StartsWith('Scripts/')) {
            throw "The built module holds '$relative', which does not belong in the package."
        }
    }
}

function Assert-Parse {
    <#
    .SYNOPSIS
        Refuses a module file that does not parse.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$File
    )

    $errors = $null
    $null = [Parser]::ParseFile($File, [ref]$null, [ref]$errors)
    if ($errors.Count -gt 0) {
        $first = $errors[0]
        $line = $first.Extent.StartLineNumber
        throw "The built module file does not parse at line ${line}: $($first.Message)"
    }
}

function Assert-Analyzed {
    <#
    .SYNOPSIS
        Refuses a file the analyzer has something to say about. A crash of the
        analyzer itself is retried, and refused if it persists.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$File
    )

    Import-Module PSScriptAnalyzer
    $found = $null
    foreach ($attempt in 1..5) {
        try {
            $found = @(Invoke-ScriptAnalyzer -Path $File)
            break
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    }

    if ($null -eq $found) {
        throw 'PSScriptAnalyzer did not run on the built module in five attempts.'
    }

    if ($found.Count -gt 0) {
        $first = $found[0]
        throw "PSScriptAnalyzer found $($found.Count) problem(s) in the built module; " +
        "the first is $($first.RuleName) at line $($first.Line): $($first.Message)"
    }
}

function Get-ImportedExport {
    <#
    .SYNOPSIS
        Imports the built module in a fresh process and returns the function
        names it exports; refuses one that does not import.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Manifest,

        [Parameter(Mandatory)]
        [string]$SourceRoot
    )

    $name = 'import-' + [guid]::NewGuid().ToString('N') + '.ps1'
    $script = Join-Path -Path ([Path]::GetTempPath()) -ChildPath $name
    $quotedRoot = $SourceRoot.Replace("'", "''")
    $quotedManifest = $Manifest.Replace("'", "''")
    $code = @"
`$ErrorActionPreference = 'Stop'
`$env:PSModulePath = '$quotedRoot' + [IO.Path]::PathSeparator + `$env:PSModulePath
`$module = Import-Module '$quotedManifest' -PassThru
`$module.ExportedFunctions.Keys | Sort-Object
"@
    try {
        [File]::WriteAllText($script, $code)
        $names = @(& pwsh -NoProfile -File $script)
        if ($LASTEXITCODE -ne 0) {
            throw "A fresh process could not import the built module (exit $LASTEXITCODE)."
        }

        return $names
    }
    finally {
        Remove-Item -LiteralPath $script -Force -ErrorAction SilentlyContinue
    }
}

$folder = [Path]::GetFullPath($Path)
if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
    throw "There is no built module folder at '$folder'."
}

$module = Split-Path -Path $folder -Leaf
Assert-Content -Folder $folder -Module $module
$psm1 = Join-Path $folder "$module.psm1"
$manifestPath = Join-Path $folder "$module.psd1"
Assert-Parse -File $psm1

$sourceRoot = [Path]::GetFullPath($SourceRoot)
$before = $env:PSModulePath
try {
    $env:PSModulePath = $sourceRoot + [Path]::PathSeparator + $before
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
}
finally {
    $env:PSModulePath = $before
}

Assert-Analyzed -File $psm1
$exported = @(Get-ImportedExport -Manifest $manifestPath -SourceRoot $sourceRoot)
$listed = @((Import-PowerShellDataFile -LiteralPath $manifestPath).FunctionsToExport | Sort-Object)
$extra = @($exported | Where-Object { $_ -notin $listed })
$missing = @($listed | Where-Object { $_ -notin $exported })
if ($extra.Count -or $missing.Count) {
    $names = @($extra + $missing) -join ', '
    throw "The built module's exports differ from its manifest: $names."
}

return [PSCustomObject]@{
    Module  = $module
    Version = $manifest.Version.ToString()
    Export  = $exported
}
