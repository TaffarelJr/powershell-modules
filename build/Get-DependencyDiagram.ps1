#Requires -Version 7.4

<#
.SYNOPSIS
    Draws the dependencies between the modules under src/ as a Mermaid diagram,
    from each manifest's RequiredModules.

.DESCRIPTION
    Every module under the source root is a node, named by its short name (the
    name without the TaffarelJr. prefix, which is how this repository refers to
    a module everywhere but on the Gallery). An arrow runs from a module to each
    module it requires. The diagram is read from the manifests, so it cannot
    drift from what the modules declare.

    Without -ReadmePath the diagram is returned as text. With it, the text
    between the markers <!-- dependency-diagram --> and <!-- /dependency-diagram -->
    in that file is replaced, which is how a module's pull request adds its own
    node to the README.

.PARAMETER SourceRoot
    The folder holding the module folders. Defaults to src/ beside this
    script's own folder.

.PARAMETER ReadmePath
    A Markdown file with the two markers. The block between them is replaced.

.EXAMPLE
    ./build/Get-DependencyDiagram.ps1

    Returns the diagram for every module under src/.

.EXAMPLE
    ./build/Get-DependencyDiagram.ps1 -ReadmePath ./README.md

    Rewrites the diagram in the root README after a module was added.
#>
using namespace System.IO

[CmdletBinding()]
[OutputType([string])]
param(
    [string]$SourceRoot = (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'src'),

    [string]$ReadmePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$prefix = 'TaffarelJr.'
$folders = @()
if (Test-Path -LiteralPath $SourceRoot -PathType Container) {
    $folders = @(Get-ChildItem -LiteralPath $SourceRoot -Directory | Sort-Object -Property Name)
}

$requires = [ordered]@{}
foreach ($folder in $folders) {
    $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $folder.FullName "$($folder.Name).psd1")
    $names = @()
    if ($manifest.ContainsKey('RequiredModules')) {
        $names = @($manifest.RequiredModules | ForEach-Object {
                $name = if ($_ -is [string]) { $_ } else { $_.ModuleName }
                $name.Substring($prefix.Length)
            } | Sort-Object)
    }

    $requires[$folder.Name.Substring($prefix.Length)] = $names
}

# A node id is the short name without its dots; the label keeps them.
function Get-NodeId {
    param([string]$Name)
    return $Name.Replace('.', '')
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('```mermaid')
$lines.Add('graph LR')
foreach ($name in $requires.Keys) {
    $lines.Add("    $(Get-NodeId $name)[""$name""]")
}

$edges = [System.Collections.Generic.List[string]]::new()
foreach ($name in $requires.Keys) {
    foreach ($required in $requires[$name]) {
        $edges.Add("    $(Get-NodeId $name) --> $(Get-NodeId $required)")
    }
}

if ($edges.Count -gt 0) {
    $lines.Add('')
    $lines.AddRange($edges)
}

$lines.Add('```')
$diagram = $lines -join "`n"

if (-not $ReadmePath) {
    return $diagram
}

$begin = '<!-- dependency-diagram -->'
$end = '<!-- /dependency-diagram -->'
$text = [File]::ReadAllText($ReadmePath)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$from = $text.IndexOf($begin, [StringComparison]::Ordinal)
$to = $text.IndexOf($end, [StringComparison]::Ordinal)
if ($from -lt 0 -or $to -lt $from) {
    throw "$ReadmePath has no $begin ... $end block."
}

$block = $begin + $newline + $diagram.Replace("`n", $newline) + $newline
$updated = $text.Substring(0, $from) + $block + $text.Substring($to)
[File]::WriteAllText($ReadmePath, $updated, [Text.UTF8Encoding]::new($false))
