function Import-RequiredModule {
    <#
    .SYNOPSIS
        Imports required modules at their minimum version or later.
    .DESCRIPTION
        A module already loaded at a good enough version is left as it is,
        along with the state it holds: this does not reload it. That includes
        a module imported by its path and not on PSModulePath, which
        Test-RequiredModule counts too. When only an older version is loaded,
        the newer one is imported from PSModulePath as well and its commands
        are the ones that run.

        Modules are imported into the global session, so they stay loaded
        for the caller rather than only inside this module.

        A module that cannot be imported is a terminating error for the call,
        and in a pipeline it stops the pipeline.
    .PARAMETER Module
        One result from Get-RequiredModule, or several, as an array
        or from the pipeline. An empty array imports nothing. A hand-made
        object works too, with a Name that is a plain module name and,
        optionally, a MinimumVersion; without one any version will do.
        Anything else is refused before anything is imported.
    .INPUTS
        System.Management.Automation.PSCustomObject. A result of
        Get-RequiredModule, with a Name and a MinimumVersion.
    .OUTPUTS
        None. The modules are imported into the session.
    .EXAMPLE
        Get-RequiredModule -Path ./RequiredModules.psd1 | Import-RequiredModule

        Imports every module the manifest names.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.RequiredModules/README.md
    .LINK
        Get-RequiredModule
    .LINK
        Assert-RequiredModule
    #>
    [CmdletBinding()]
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
                $literal = [WildcardPattern]::Escape($item.Name)
                $loaded = @(Get-Module -Name $literal)
                $minimum = $item.MinimumVersion
                $goodEnough = @($loaded.Where({ $null -eq $minimum -or $_.Version -ge $minimum }))
                if ($goodEnough.Count -gt 0) {
                    continue
                }

                $import = @{
                    Name        = $item.Name
                    Global      = $true
                    ErrorAction = 'Stop'
                }

                if ($null -ne $item.MinimumVersion) {
                    $import.MinimumVersion = $item.MinimumVersion
                }

                Import-Module @import
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
