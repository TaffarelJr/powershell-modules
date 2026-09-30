function Test-RequiredModule {
    <#
    .SYNOPSIS
        Reports whether a required module is installed
        at its minimum version or later.
    .DESCRIPTION
        A module already loaded in this session counts, even one imported by
        its path and not on PSModulePath: Import-RequiredModule leaves such a
        module as it is rather than failing to find it. That holds in this
        session only - a new process does not have the module loaded, and
        finds only what is on PSModulePath.

        Versions compare as .NET [Version] values, so a module at '5.0' does
        not meet a minimum of '5.0.0' (see Get-RequiredModule).

        Gives one answer per module, in the order given.
    .PARAMETER Module
        One result from Get-RequiredModule, or several, as an array
        or from the pipeline. An empty array gives no answer. A hand-made
        object works too, with a Name that is a plain module name and,
        optionally, a MinimumVersion; without one any installed version is
        enough. Anything else is refused.
    .INPUTS
        System.Management.Automation.PSCustomObject. A result of
        Get-RequiredModule, with a Name and a MinimumVersion.
    .OUTPUTS
        System.Boolean. True when the module is installed at its minimum
        version or later, or at any version when it has no minimum, one
        answer per module.
    .EXAMPLE
        Get-RequiredModule -Path ./RequiredModules.psd1 | Test-RequiredModule

        Returns $true or $false for each module the manifest names.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.RequiredModules/README.md
    .LINK
        Get-RequiredModule
    .LINK
        Install-RequiredModule
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Module
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            $items = foreach ($candidate in $Module) {
                Resolve-RequiredModule -Module $candidate
            }

            foreach ($item in $items) {
                $installed = Get-InstalledModuleVersion -Name $item.Name -MinimumVersion $item.MinimumVersion
                Test-MinimumVersion -InstalledVersion $installed -MinimumVersion $item.MinimumVersion
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
