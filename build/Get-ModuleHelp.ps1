#Requires -Version 7.6

<#
.SYNOPSIS
    Writes the help of every function a module exports to a JSON file.

.DESCRIPTION
    Run it in a process of its own: it imports the module, and a process that
    has imported a module keeps it. For each exported function, in name order,
    the file holds the synopsis, the description, the syntax of each parameter
    set, every parameter with its type and description, the examples, the
    input and output types, and the related links, as Get-Help reports them.

.PARAMETER Manifest
    The module's manifest (.psd1).

.PARAMETER OutputPath
    The JSON file to write.

.PARAMETER SourceRoot
    A folder holding other modules, put on PSModulePath so a module this one
    requires resolves.

.EXAMPLE
    pwsh -NoProfile -File ./build/Get-ModuleHelp.ps1 `
        -Manifest ./out/TaffarelJr.Tally/TaffarelJr.Tally.psd1 -OutputPath ./help.json

    Writes the help of the built Tally module to ./help.json.
#>
using namespace System.IO
using namespace System.Text

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Manifest,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [string]$SourceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-OptionalValue {
    <#
    .SYNOPSIS
        Returns a property of an object, or nothing when it has none.
    #>
    param(
        $Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }
}

function Get-HelpItem {
    <#
    .SYNOPSIS
        Returns the items of one section of a command's help, or nothing when
        the help has no such section.
    #>
    param(
        [Parameter(Mandatory)]
        $Help,

        [Parameter(Mandatory)]
        [string]$Section,

        [Parameter(Mandatory)]
        [string]$Item
    )

    $container = Get-OptionalValue -Object $Help -Name $Section
    return Get-OptionalValue -Object $container -Name $Item
}

function Select-NonNull {
    <#
    .SYNOPSIS
        Returns the values of a collection that is not null, one at a time.
    #>
    param(
        $Value
    )

    $Value | Where-Object { $null -ne $_ }
}

function Get-ParagraphText {
    <#
    .SYNOPSIS
        Returns the text of help paragraphs, joined, with LF line endings.
    #>
    param(
        $Paragraph,

        [string]$Separator = "`n`n"
    )

    $texts = Select-NonNull -Value $Paragraph | ForEach-Object { [string]$_.Text }
    return ((@($texts) -join $Separator) -replace "`r`n", "`n").Trim()
}

function Get-CommandHelp {
    <#
    .SYNOPSIS
        Returns what one command's help says, as plain data.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $help = Get-Help -Name "$Module\$Name" -Full
    $syntax = (Get-Command -Name $Name -Module $Module -Syntax) -split '\r?\n'
    $description = Get-OptionalValue -Object $help -Name 'description'
    $parameters = Get-HelpItem -Help $help -Section 'parameters' -Item 'parameter'
    $examples = Get-HelpItem -Help $help -Section 'examples' -Item 'example'
    $inputs = Get-HelpItem -Help $help -Section 'inputTypes' -Item 'inputType'
    $outputs = Get-HelpItem -Help $help -Section 'returnValues' -Item 'returnValue'
    $links = Get-HelpItem -Help $help -Section 'relatedLinks' -Item 'navigationLink'

    return [PSCustomObject]@{
        Name        = $Name
        Synopsis    = ([string]$help.Synopsis -replace "`r`n", "`n").Trim()
        Description = Get-ParagraphText -Paragraph $description
        Syntax      = @($syntax | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        Parameters  = @(Select-NonNull -Value $parameters | ForEach-Object {
                [PSCustomObject]@{
                    Name          = [string]$_.name
                    Type          = [string](Get-OptionalValue -Object $_.type -Name 'name')
                    Required      = [string]$_.required -eq 'true'
                    Position      = [string]$_.position
                    PipelineInput = [string]$_.pipelineInput
                    DefaultValue  = [string]$_.defaultValue
                    Description   = Get-ParagraphText -Paragraph $_.description
                }
            })
        Examples    = @(Select-NonNull -Value $examples | ForEach-Object {
                [PSCustomObject]@{
                    Code    = ([string]$_.code).Trim()
                    Remarks = Get-ParagraphText -Paragraph $_.remarks -Separator "`n"
                }
            })
        Inputs      = @(Select-NonNull -Value $inputs | ForEach-Object {
                [string](Get-OptionalValue -Object $_.type -Name 'name')
            })
        Outputs     = @(Select-NonNull -Value $outputs | ForEach-Object {
                [string](Get-OptionalValue -Object $_.type -Name 'name')
            })
        Links       = @(Select-NonNull -Value $links | ForEach-Object {
                [PSCustomObject]@{
                    Text = [string](Get-OptionalValue -Object $_ -Name 'linkText')
                    Uri  = [string](Get-OptionalValue -Object $_ -Name 'uri')
                }
            })
    }
}

if ($SourceRoot) {
    $root = [Path]::GetFullPath($SourceRoot)
    $env:PSModulePath = $root + [Path]::PathSeparator + $env:PSModulePath
}

$module = Import-Module -Name ([Path]::GetFullPath($Manifest)) -PassThru -Force
$names = [string[]]@($module.ExportedFunctions.Keys)
[Array]::Sort($names, [StringComparer]::OrdinalIgnoreCase)
$all = @($names | ForEach-Object { Get-CommandHelp -Module $module.Name -Name $_ })
$json = ConvertTo-Json -InputObject $all -Depth 8
[File]::WriteAllText([Path]::GetFullPath($OutputPath), $json, [UTF8Encoding]::new($false))
