#Requires -Version 7.4

<#
.SYNOPSIS
    Builds one or more modules under src/ into the single-file shape the
    published package ships: one .psm1 holding every function.

.DESCRIPTION
    The repository keeps one function per file because that is what reads,
    reviews and diffs well. A module imports faster as one file, since the
    engine reads and scans each dot-sourced file separately and security
    software scans each one too: a module of a few dozen functions imports
    in a fraction of a second as one file where the file-per-function layout
    takes seconds. So the published package is built.

    For each module the build concatenates Private/*.ps1 then Public/*.ps1,
    each in ordinal order, between the root .psm1's own preamble (everything
    before its dot-sourcing loop) and its tail (from Export-ModuleMember on),
    hoists every "using namespace" line to one sorted set under #Requires,
    marks each source file with "#region <relative path>" and "#endregion"
    so a line in a stack trace maps back to its source, and writes the
    result as CRLF without a byte order mark. The manifest, README.md,
    CHANGELOG.md and a Scripts/ folder are copied as they are. Nothing else
    goes into the output folder, because the packer packs every file in it.

    A source file under Private/ or Public/ that uses $PSScriptRoot or
    $PSCommandPath is refused: in the built module those name the module
    root, not the function's own file. Resolve such a path from
    $ExecutionContext.SessionState.Module.ModuleBase instead. The built file
    is parsed, and its manifest is checked with Test-ModuleManifest, with
    the source root on PSModulePath so RequiredModules resolve.

.PARAMETER Name
    One or more module folder names under the source root, such as
    TaffarelJr.TestKit. A single comma-joined token is split, since a
    caller outside PowerShell (pwsh -File, a CI step) binds one token per
    array parameter.

.PARAMETER All
    Builds every module under the source root.

.PARAMETER SourceRoot
    The folder holding the module folders. Defaults to src/ beside this
    script's own folder.

.PARAMETER OutputPath
    The folder the built modules are written under, one subfolder per
    module. Defaults to out/ beside this script's own folder. A module's
    subfolder is emptied before it is written.

.PARAMETER PassThru
    Returns one object per module built: Name, Version, Prerelease, Path
    (the output folder), Files (the relative paths written) and Functions
    (how many source files went in).

.EXAMPLE
    ./build/Build-Module.ps1 -Name TaffarelJr.TestKit

    Builds one module into out/TaffarelJr.TestKit.

.EXAMPLE
    ./build/Build-Module.ps1 -All -PassThru | Format-Table Name, Version, Functions

    Builds every module and lists what was built.

.NOTES
    Every default is anchored on $PSScriptRoot, so the script behaves the
    same from the repository root or from inside build/.
#>
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Management.Automation.Language
using namespace System.Text

[CmdletBinding(DefaultParameterSetName = 'Name')]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory, ParameterSetName = 'Name', Position = 0)]
    [string[]]$Name,

    [Parameter(Mandatory, ParameterSetName = 'All')]
    [switch]$All,

    [string]$SourceRoot = (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'src'),

    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'out'),

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceRoot = [Path]::GetFullPath($SourceRoot)
$outputRoot = [Path]::GetFullPath($OutputPath)
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "No source root at '$sourceRoot'."
}

$names = @(if ($All) {
        Get-ChildItem -LiteralPath $sourceRoot -Directory | Sort-Object Name | ForEach-Object Name
    }
    else {
        $Name | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    })
if ($names.Count -eq 0) {
    throw '-Name names no module.'
}

$utf8 = [UTF8Encoding]::new($false)
$ordinal = [StringComparer]::Ordinal

function Read-SourceFile {
    <#
    .SYNOPSIS
        Parses one source file and returns its lines, its using lines and
        its parse errors; refuses a file-relative path variable.
    #>
    param(
        [Parameter(Mandatory)]
        [FileInfo]$File,

        [Parameter(Mandatory)]
        [bool]$IsRoot
    )

    $tokens = $null
    $errors = $null
    $ast = [Parser]::ParseFile($File.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $first = $errors[0]
        throw "$($File.FullName):$($first.Extent.StartLineNumber):$($first.Extent.StartColumnNumber): $($first.Message)"
    }

    $usings = $ast.FindAll({ param($node) $node -is [UsingStatementAst] }, $true)
    foreach ($using in $usings) {
        if ($using.UsingStatementKind -ne [UsingStatementKind]::Namespace) {
            throw "$($File.FullName):$($using.Extent.StartLineNumber): " +
            "only 'using namespace' can be hoisted into a single file."
        }
    }

    if (-not $IsRoot) {
        $fileRelative = $ast.FindAll({
                param($node)
                $node -is [VariableExpressionAst] -and
                $node.VariablePath.UserPath -in 'PSScriptRoot', 'PSCommandPath'
            }, $true)
        if ($fileRelative.Count -gt 0) {
            $hit = $fileRelative[0]
            throw "$($File.FullName):$($hit.Extent.StartLineNumber): uses `$$($hit.VariablePath.UserPath), " +
            'which is the module root in a single-file build; resolve the path from ' +
            '$ExecutionContext.SessionState.Module.ModuleBase instead.'
        }
    }

    return [PSCustomObject]@{
        Lines  = [File]::ReadAllLines($File.FullName)
        Usings = @($usings | ForEach-Object { $_.Name.Value })
        Ast    = $ast
    }
}

function Build-OneModule {
    <#
    .SYNOPSIS
        Builds one module folder into its output folder and returns the
        result object.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    $moduleRoot = Join-Path $sourceRoot $ModuleName
    if (-not (Test-Path -LiteralPath $moduleRoot -PathType Container)) {
        throw "No module folder at '$moduleRoot'."
    }

    foreach ($required in "$ModuleName.psd1", "$ModuleName.psm1", 'README.md', 'CHANGELOG.md') {
        if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot $required) -PathType Leaf)) {
            throw "Module '$ModuleName' has no $required."
        }
    }

    $sourceFiles = [List[FileInfo]]::new()
    foreach ($folder in 'Private', 'Public') {
        $path = Join-Path $moduleRoot $folder
        if (Test-Path -LiteralPath $path -PathType Container) {
            $files = [FileInfo[]]@(Get-ChildItem -LiteralPath $path -Filter *.ps1 -File)
            [Array]::Sort($files, [Comparison[FileInfo]] { param($a, $b) $ordinal.Compare($a.Name, $b.Name) })
            $sourceFiles.AddRange($files)
        }
    }

    # Every file is parsed and checked before anything is written.
    $root = Read-SourceFile -File (Get-Item -LiteralPath (Join-Path $moduleRoot "$ModuleName.psm1")) -IsRoot $true
    $parsed = [List[PSCustomObject]]::new()
    $usingSet = [SortedSet[string]]::new($ordinal)
    foreach ($using in $root.Usings) { $null = $usingSet.Add($using) }
    foreach ($file in $sourceFiles) {
        $source = Read-SourceFile -File $file -IsRoot $false
        foreach ($using in $source.Usings) { $null = $usingSet.Add($using) }
        $parsed.Add([PSCustomObject]@{ File = $file; Lines = $source.Lines })
    }

    # The root splits at its one dot-sourcing loop: preamble before, tail after.
    $loops = @($root.Ast.FindAll({
                param($node)
                $node -is [ForEachStatementAst] -and
                $node.Extent.Text -match 'Get-ChildItem' -and $node.Extent.Text -match '\.\s*\$file\.FullName'
            }, $false))
    if ($loops.Count -ne 1) {
        throw "Module '$ModuleName': expected one dot-sourcing foreach in the root .psm1, found $($loops.Count)."
    }

    $loop = $loops[0]
    $rootLines = $root.Lines
    $preamble = @($rootLines[0..($loop.Extent.StartLineNumber - 2)] | Where-Object {
            $_ -notmatch '^#Requires\s' -and $_ -notmatch '^using namespace\s'
        })
    $tail = @($rootLines[($loop.Extent.EndLineNumber)..($rootLines.Count - 1)])
    while ($preamble.Count -gt 0 -and $preamble[-1] -eq '') { $preamble = $preamble[0..($preamble.Count - 2)] }
    while ($tail.Count -gt 0 -and $tail[0] -eq '') { $tail = $tail[1..($tail.Count - 1)] }

    $lines = [List[string]]::new()
    $lines.Add('#Requires -Version 7.4')
    foreach ($using in $usingSet) { $lines.Add("using namespace $using") }
    $lines.Add('')
    $lines.AddRange([string[]]$preamble)
    $lines.Add('')
    foreach ($entry in $parsed) {
        $relative = [Path]::GetRelativePath($moduleRoot, $entry.File.FullName).Replace('\', '/')
        $lines.Add("#region $relative")
        foreach ($line in $entry.Lines) {
            # A hoisted line becomes an empty one, so every source line keeps its
            # offset from the region marker.
            if ($line -match '^using namespace\s') { $lines.Add('') } else { $lines.Add($line) }
        }

        $lines.Add("#endregion $relative")
        $lines.Add('')
    }

    $lines.AddRange([string[]]$tail)

    $outputFolder = Join-Path $outputRoot $ModuleName
    if (Test-Path -LiteralPath $outputFolder) {
        Remove-Item -LiteralPath $outputFolder -Recurse -Force
    }

    $null = New-Item -ItemType Directory -Path $outputFolder
    $written = [List[string]]::new()
    $psm1 = Join-Path $outputFolder "$ModuleName.psm1"
    [File]::WriteAllText($psm1, (($lines -join "`r`n") + "`r`n"), $utf8)
    $written.Add("$ModuleName.psm1")
    foreach ($copy in "$ModuleName.psd1", 'README.md', 'CHANGELOG.md') {
        Copy-Item -LiteralPath (Join-Path $moduleRoot $copy) -Destination $outputFolder
        $written.Add($copy)
    }

    $scripts = Join-Path $moduleRoot 'Scripts'
    if (Test-Path -LiteralPath $scripts -PathType Container) {
        Copy-Item -LiteralPath $scripts -Destination $outputFolder -Recurse
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $outputFolder 'Scripts') -Recurse -File) {
            $written.Add([Path]::GetRelativePath($outputFolder, $file.FullName).Replace('\', '/'))
        }
    }

    $errors = $null
    $null = [Parser]::ParseFile($psm1, [ref]$null, [ref]$errors)
    if ($errors.Count -gt 0) {
        $first = $errors[0]
        throw "Built '$psm1' does not parse at line $($first.Extent.StartLineNumber): $($first.Message)"
    }

    $separator = [Path]::PathSeparator
    $modulePathBefore = $env:PSModulePath
    try {
        $env:PSModulePath = "$sourceRoot$separator$modulePathBefore"
        $manifest = Test-ModuleManifest -Path (Join-Path $outputFolder "$ModuleName.psd1") -ErrorAction Stop
    }
    finally {
        $env:PSModulePath = $modulePathBefore
    }

    $data = Import-PowerShellDataFile -LiteralPath (Join-Path $outputFolder "$ModuleName.psd1")
    $prerelease = ''
    if ($data.ContainsKey('PrivateData') -and $data.PrivateData.ContainsKey('PSData')) {
        $prerelease = [string]$data.PrivateData.PSData['Prerelease']
    }

    return [PSCustomObject]@{
        Name       = $ModuleName
        Version    = $manifest.Version
        Prerelease = $prerelease
        Path       = $outputFolder
        Files      = $written.ToArray()
        Functions  = $parsed.Count
    }
}

foreach ($moduleName in $names) {
    $result = Build-OneModule -ModuleName $moduleName
    Write-Verbose "Built $($result.Name) $($result.Version) ($($result.Functions) files) into $($result.Path)"
    if ($PassThru) {
        $result
    }
}
