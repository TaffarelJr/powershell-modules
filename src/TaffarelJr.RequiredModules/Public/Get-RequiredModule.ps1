using namespace System.Collections

function Get-RequiredModule {
    <#
    .SYNOPSIS
        Reads a required-modules manifest,
        returning one object per required module, in name order.
    .DESCRIPTION
        The manifest is this module's own format: a hashtable keyed by module
        name, each value a hashtable with, optionally, MinimumVersion and
        DocumentationUrl. An entry with no MinimumVersion (an empty hashtable,
        say) means any version of the module will do. A RequiredModules.psd1
        written for PSDepend, or a PSResourceGet -RequiredResourceFile, has
        another shape and is refused with a message naming the entry.

        -Path is read with Import-PowerShellDataFile, not dot-sourced -
        a manifest is data, and parsing it as data means
        it can never run arbitrary code.
        Either way, every entry is validated before use,
        so a malformed manifest fails with a clear message here
        instead of a confusing error somewhere else.

        MinimumVersion is a plain numeric version such as '5.0.0',
        written as a string. A prerelease label is not supported:
        a prerelease counts by its numeric part. Versions compare as .NET
        [Version] values, the way Import-Module -MinimumVersion compares them,
        so a missing part is lower than a zero: a module whose ModuleVersion
        is '5.0' does not meet a minimum of '5.0.0'. Write the minimum with as
        many parts as the module's own version has.

        A manifest that is missing, cannot be read, or holds a mistaken entry
        is a terminating error for the call, and in a pipeline it stops the
        pipeline. The error for a file that cannot be read names the file and
        the rule it broke, and never quotes the file's text, which may hold a
        secret.
    .PARAMETER Path
        The path to a .psd1 file holding the manifest.
        Binds from the FullName or PSPath of a piped file.
    .PARAMETER Data
        The manifest itself, in the same shape -
        for a caller that builds it in code instead of
        maintaining a separate .psd1 file. Accepts pipeline input,
        one manifest after another.
    .INPUTS
        System.String. The path of a manifest file; or any object with a
        FullName, PSPath, or Path property, such as the files Get-ChildItem
        returns.

        System.Collections.IDictionary. A manifest built in code.
    .OUTPUTS
        System.Management.Automation.PSCustomObject. One per module: Name,
        MinimumVersion (a [Version], or $null when the entry gives none), and
        DocumentationUrl ($null when the manifest gives none).
    .EXAMPLE
        Get-RequiredModule -Path ./RequiredModules.psd1 | Import-RequiredModule

        Imports every module the manifest names.
    .EXAMPLE
        Get-RequiredModule -Data @{
            Pester = @{
                MinimumVersion   = '5.3.0'
                DocumentationUrl = 'https://pester.dev'
            }
        }

        Returns one object, for Pester 5.3.0 or later.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.RequiredModules/README.md
    .LINK
        Assert-RequiredModule
    .LINK
        Test-RequiredModule
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByData')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'ByPath',
            ValueFromPipelineByPropertyName
        )]
        [Alias('FullName', 'PSPath')]
        [string]$Path,

        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'ByData',
            ValueFromPipeline
        )]
        [IDictionary]$Data
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
                if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
                    throw "RequiredModules manifest not found: $Path"
                }

                try {
                    $Data = Import-PowerShellDataFile -LiteralPath $Path
                }
                catch {
                    # Not $_.Exception.Message: for a file that holds an
                    # expression it quotes the whole file, secrets included.
                    throw ("RequiredModules manifest '$Path' could not be read: " +
                        'it is not a PowerShell data file. A data file holds one hashtable of literal values - ' +
                        'no variables, commands, casts or operators - and has no syntax errors.')
                }
            }

            # PSBase: a module named Keys would otherwise be read in place of
            # every name.
            $names = @($Data.PSBase.Keys | Sort-Object)
            foreach ($name in $names) {
                Get-RequiredModuleEntry -Name $name -Entry $Data[$name]
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
