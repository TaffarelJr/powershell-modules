function Update-RequiredModule {
    <#
    .SYNOPSIS
        Brings the required modules to the newest version the Gallery has.
    .DESCRIPTION
        Every module given is updated with Update-Module, whether or not it
        already meets its minimum version, so a script can refresh what a
        manifest names. A module that is not installed is installed instead,
        at the newest version, as Install-RequiredModule installs it. Nothing
        asks first, unless given -Confirm.

        Each module is checked before the first one is touched, so a mistaken
        object changes nothing. It updates and returns: it does not look the
        module up afterwards. Assert-RequiredModule is the one that verifies
        a minimum version.

        -WhatIf and -Confirm name each module that would be updated or
        installed. With -WhatIf nothing is changed and nothing is returned.

        A failed update is a terminating error for the call, and in a
        pipeline it stops the pipeline: the modules before it stay updated
        and the ones after it are not tried.

        With -Verbose, shows the Update-Module command before it runs.
    .PARAMETER Module
        One result from Get-RequiredModule, or several, as an array or from
        the pipeline. An empty array updates nothing. A hand-made object
        works too, with a Name that is a plain module name; its
        MinimumVersion, if any, is not used. Anything else is refused.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Management.Automation.PSCustomObject. A result of
        Get-RequiredModule, with a Name.
    .OUTPUTS
        None. The modules are updated.
    .EXAMPLE
        Get-RequiredModule -Path ./RequiredModules.psd1 | Update-RequiredModule

        Updates every module the manifest names to its newest version, and
        installs any that is missing.
    .EXAMPLE
        Get-RequiredModule -Path ./RequiredModules.psd1 |
            Update-RequiredModule -WhatIf

        Names each module that would be updated, and changes nothing.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.RequiredModules/README.md
    .LINK
        Install-RequiredModule
    .LINK
        Assert-RequiredModule
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Module
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $items = foreach ($candidate in $Module) {
                Resolve-RequiredModule -Module $candidate
            }

            foreach ($item in $items) {
                if (-not $PSCmdlet.ShouldProcess($item.Name, 'Update module')) {
                    continue
                }

                if ($null -eq (Get-InstalledModuleVersion -Name $item.Name)) {
                    Install-RequiredModule -Module $item -WhatIf:$false -Confirm:$false
                    continue
                }

                Write-Verbose "Running Update-Module -Name $($item.Name) -Force"

                # Update-Module reports most failures as non-terminating errors,
                # which this module's own preference does not reach into. Nor do
                # this call's -WhatIf and -Confirm: it would follow the session's,
                # and ask or preview again after the answer above.
                Update-Module -Name $item.Name -Force -ErrorAction Stop -WhatIf:$false -Confirm:$false
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
