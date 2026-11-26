#Requires -Version 7.6

<#
.SYNOPSIS
    Builds one or more modules under src/ into the single-file shape the
    published package ships: one .psm1 holding every function.

.DESCRIPTION
    The repository keeps one function per file because that reads, reviews
    and diffs well. A module imports faster as one file, since the engine
    reads and scans each dot-sourced file separately and security software
    scans each one too. So the published package is built.

    For each module the build concatenates Private/*.ps1 then Public/*.ps1,
    each in ordinal order, between the root .psm1's own preamble (everything
    before its dot-sourcing loop) and its tail (from the loop on). The root's
    #Requires lines come first, then every "using namespace" line of the root
    and of the function files as one sorted set. Each source file is marked
    with "#region <relative path>" and "#endregion", so a line in a stack
    trace maps back to its source. The result is CRLF without a byte order
    mark. The manifest, README.md and a Scripts/ folder are copied as they
    are. Nothing else goes into the output folder, because the packer packs
    every file in it. A CHANGELOG.md is not copied: the release writes one.

    A source file under Private/ or Public/ that uses $PSScriptRoot or
    $PSCommandPath is refused: in the built module those name the module
    root, not the function's own file. Resolve such a path from
    $ExecutionContext.SessionState.Module.ModuleBase instead. Every source
    file is parsed and checked before anything is written. The built file is
    parsed again, and its manifest is checked with Test-ModuleManifest, with
    the source root on PSModulePath so RequiredModules resolve.

.PARAMETER Name
    One or more module folder names under the source root, such as
    TaffarelJr.Tally. A single comma-joined token is split, since a caller
    outside PowerShell (pwsh -File, a CI step) binds one token per array
    parameter.

.PARAMETER All
    Builds every module under the source root.

.PARAMETER SourceRoot
    The folder holding the module folders. Defaults to src/ beside this
    script's own folder.

.PARAMETER OutputPath
    The folder the built modules are written under, one subfolder per module.
    Defaults to out/ beside this script's own folder. A module's subfolder is
    emptied before it is written.

.PARAMETER PassThru
    Returns one object per module built: Name, Version, Prerelease, Path (the
    output folder), Files (the relative paths written) and Functions (how
    many source files went in).

.EXAMPLE
    ./build/Build-Module.ps1 -Name TaffarelJr.Tally

    Builds one module into out/TaffarelJr.Tally.

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

function Read-SourceFile {
    <#
    .SYNOPSIS
        Parses one source file and returns its lines and its using lines;
        refuses one that does not parse, a using that is not a using
        namespace, and a function file that uses a file-relative variable.
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
    $usings = @($ast.FindAll({ param($node) $node -is [UsingStatementAst] }, $true))
    foreach ($using in $usings) {
        if ($using.UsingStatementKind -ne [UsingStatementKind]::Namespace) {
            throw "$($File.FullName):$($using.Extent.StartLineNumber): " +
            "only 'using namespace' can be hoisted into a single file."
        }
    }

    if ($errors.Count -gt 0) {
        $first = $errors[0]
        $line = $first.Extent.StartLineNumber
        $column = $first.Extent.StartColumnNumber
        throw "$($File.FullName):${line}:${column}: $($first.Message)"
    }

    if (-not $IsRoot) {
        $fileRelative = @($ast.FindAll({
                    param($node)
                    $node -is [VariableExpressionAst] -and
                    $node.VariablePath.UserPath -in 'PSScriptRoot', 'PSCommandPath'
                }, $true))
        if ($fileRelative.Count -gt 0) {
            $hit = $fileRelative[0]
            throw "$($File.FullName):$($hit.Extent.StartLineNumber): " +
            "uses `$$($hit.VariablePath.UserPath), which is the module root in a " +
            'single-file build; resolve the path from ' +
            '$ExecutionContext.SessionState.Module.ModuleBase instead.'
        }
    }

    return [PSCustomObject]@{
        Lines     = [File]::ReadAllLines($File.FullName)
        Using     = @($usings | ForEach-Object { $_.Name.Value })
        UsingLine = @($usings | ForEach-Object { $_.Extent.StartLineNumber })
        Ast       = $ast
    }
}

function Get-ModuleSourceFile {
    <#
    .SYNOPSIS
        Returns a module's function files: Private before Public, each folder
        in ordinal order.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleRoot
    )

    $ordinal = [StringComparer]::Ordinal
    foreach ($folder in 'Private', 'Public') {
        $path = Join-Path $ModuleRoot $folder
        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            continue
        }

        $files = [FileInfo[]]@(Get-ChildItem -LiteralPath $path -Filter *.ps1 -File)
        $byName = [Comparison[FileInfo]] {
            param($a, $b)
            $ordinal.Compare($a.Name, $b.Name)
        }
        [Array]::Sort($files, $byName)
        $files
    }
}

function Get-RootPart {
    <#
    .SYNOPSIS
        Splits a root module at its one dot-sourcing loop: the #Requires
        lines, the preamble before the loop, and the tail after it.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [PSCustomObject]$Root
    )

    $loops = @($Root.Ast.FindAll({
                param($node)
                $node -is [ForEachStatementAst] -and
                $node.Extent.Text -match 'Get-ChildItem' -and
                $node.Extent.Text -match '\.\s*\$file\.FullName'
            }, $false))
    if ($loops.Count -ne 1) {
        throw "Module '$ModuleName': expected one dot-sourcing foreach in the root " +
        ".psm1, found $($loops.Count)."
    }

    $lines = $Root.Lines
    $loop = $loops[0]
    $before = @(for ($i = 0; $i -lt $loop.Extent.StartLineNumber - 1; $i++) {
            if (($i + 1) -notin $Root.UsingLine) { $lines[$i] }
        })
    $after = @(for ($i = $loop.Extent.EndLineNumber; $i -lt $lines.Count; $i++) { $lines[$i] })

    return [PSCustomObject]@{
        Requires = @($before | Where-Object { $_ -match '^\s*#Requires\s' })
        Preamble = Get-TrimmedLine @($before | Where-Object { $_ -notmatch '^\s*#Requires\s' })
        Tail     = Get-TrimmedLine $after
    }
}

function Get-TrimmedLine {
    <#
    .SYNOPSIS
        Returns the lines without blank lines at either end.
    #>
    param(
        [AllowEmptyCollection()]
        [string[]]$Line
    )

    $start = 0
    $end = $Line.Count - 1
    while ($start -le $end -and $Line[$start] -eq '') { $start++ }
    while ($end -ge $start -and $Line[$end] -eq '') { $end-- }
    if ($end -lt $start) {
        return
    }

    $Line[$start..$end]
}

function Format-BuiltModule {
    <#
    .SYNOPSIS
        Returns the lines of the single built .psm1.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleRoot,

        [Parameter(Mandatory)]
        [PSCustomObject]$Part,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Using,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Source
    )

    $lines = [List[string]]::new()
    $lines.AddRange([string[]]$Part.Requires)
    foreach ($namespace in $Using) { $lines.Add("using namespace $namespace") }
    $lines.Add('')
    if ($Part.Preamble) {
        $lines.AddRange([string[]]$Part.Preamble)
        $lines.Add('')
    }

    foreach ($entry in $Source) {
        $relative = [Path]::GetRelativePath($ModuleRoot, $entry.File.FullName).Replace('\', '/')
        $lines.Add("#region $relative")
        for ($i = 0; $i -lt $entry.Lines.Count; $i++) {
            $hoisted = ($i + 1) -in $entry.UsingLine
            $lines.Add($hoisted ? '' : $entry.Lines[$i])
        }

        $lines.Add("#endregion $relative")
        $lines.Add('')
    }

    if ($Part.Tail) {
        $lines.AddRange([string[]]$Part.Tail)
    }

    return $lines.ToArray()
}

function Write-ModuleOutput {
    <#
    .SYNOPSIS
        Empties a module's output folder and writes the built .psm1 into it
        with the manifest, the README and any Scripts folder; returns the
        folder.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleRoot,

        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$OutputRoot,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Line
    )

    $folder = Join-Path $OutputRoot $ModuleName
    if (Test-Path -LiteralPath $folder) {
        Remove-Item -LiteralPath $folder -Recurse -Force
    }

    $null = New-Item -ItemType Directory -Path $folder
    $psm1 = Join-Path $folder "$ModuleName.psm1"
    $text = ($Line -join "`r`n") + "`r`n"
    [File]::WriteAllText($psm1, $text, [UTF8Encoding]::new($false))
    foreach ($copy in "$ModuleName.psd1", 'README.md') {
        Copy-Item -LiteralPath (Join-Path $ModuleRoot $copy) -Destination $folder
    }

    $scripts = Join-Path $ModuleRoot 'Scripts'
    if (Test-Path -LiteralPath $scripts -PathType Container) {
        Copy-Item -LiteralPath $scripts -Destination $folder -Recurse
    }

    return $folder
}

function Test-BuiltModule {
    <#
    .SYNOPSIS
        Parses the built .psm1 and checks the built manifest with the source
        root on PSModulePath; returns what Test-ModuleManifest returns.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Folder,

        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$SourceRoot
    )

    $psm1 = Join-Path $Folder "$ModuleName.psm1"
    $errors = $null
    $null = [Parser]::ParseFile($psm1, [ref]$null, [ref]$errors)
    if ($errors.Count -gt 0) {
        $first = $errors[0]
        $line = $first.Extent.StartLineNumber
        throw "Built '$psm1' does not parse at line ${line}: $($first.Message)"
    }

    $before = $env:PSModulePath
    try {
        $env:PSModulePath = $SourceRoot + [Path]::PathSeparator + $before
        return Test-ModuleManifest -Path (Join-Path $Folder "$ModuleName.psd1") -ErrorAction Stop
    }
    finally {
        $env:PSModulePath = $before
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
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$SourceRoot,

        [Parameter(Mandatory)]
        [string]$OutputRoot
    )

    $moduleRoot = Join-Path $SourceRoot $ModuleName
    if (-not (Test-Path -LiteralPath $moduleRoot -PathType Container)) {
        throw "No module folder at '$moduleRoot'."
    }

    foreach ($required in "$ModuleName.psd1", "$ModuleName.psm1", 'README.md') {
        if (-not (Test-Path -LiteralPath (Join-Path $moduleRoot $required) -PathType Leaf)) {
            throw "Module '$ModuleName' has no $required."
        }
    }

    $rootFile = Get-Item -LiteralPath (Join-Path $moduleRoot "$ModuleName.psm1")
    $root = Read-SourceFile -File $rootFile -IsRoot $true
    $source = @(foreach ($file in Get-ModuleSourceFile -ModuleRoot $moduleRoot) {
            $read = Read-SourceFile -File $file -IsRoot $false
            [PSCustomObject]@{
                File      = $file
                Lines     = $read.Lines
                Using     = $read.Using
                UsingLine = $read.UsingLine
            }
        })
    $part = Get-RootPart -ModuleName $ModuleName -Root $root

    $namespaces = [SortedSet[string]]::new([StringComparer]::Ordinal)
    foreach ($name in @($root.Using) + @($source | ForEach-Object { $_.Using })) {
        $null = $namespaces.Add($name)
    }

    $lines = Format-BuiltModule -ModuleRoot $moduleRoot -Part $part `
        -Using $namespaces -Source $source
    $folder = Write-ModuleOutput -ModuleRoot $moduleRoot -ModuleName $ModuleName `
        -OutputRoot $OutputRoot -Line $lines
    $manifest = Test-BuiltModule -Folder $folder -ModuleName $ModuleName `
        -SourceRoot $SourceRoot

    $data = Import-PowerShellDataFile -LiteralPath (Join-Path $folder "$ModuleName.psd1")
    $prerelease = ''
    if ($data.ContainsKey('PrivateData') -and $data.PrivateData.ContainsKey('PSData')) {
        $prerelease = [string]$data.PrivateData.PSData['Prerelease']
    }

    $written = @(Get-ChildItem -LiteralPath $folder -Recurse -File |
            ForEach-Object { [Path]::GetRelativePath($folder, $_.FullName).Replace('\', '/') })
    [Array]::Sort($written, [StringComparer]::Ordinal)

    return [PSCustomObject]@{
        Name       = $ModuleName
        Version    = $manifest.Version
        Prerelease = $prerelease
        Path       = $folder
        Files      = $written
        Functions  = $source.Count
    }
}

$sourceRoot = [Path]::GetFullPath($SourceRoot)
$outputRoot = [Path]::GetFullPath($OutputPath)
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "No source root at '$sourceRoot'."
}

$names = @(if ($All) {
        Get-ChildItem -LiteralPath $sourceRoot -Directory | Sort-Object Name | ForEach-Object Name
    }
    else {
        $Name |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    })
if ($names.Count -eq 0) {
    throw '-Name names no module.'
}

foreach ($moduleName in $names) {
    $result = Build-OneModule -ModuleName $moduleName -SourceRoot $sourceRoot `
        -OutputRoot $outputRoot
    $built = "$($result.Name) $($result.Version) ($($result.Functions) files)"
    Write-Verbose "Built $built into $($result.Path)"
    if ($PassThru) {
        $result
    }
}
