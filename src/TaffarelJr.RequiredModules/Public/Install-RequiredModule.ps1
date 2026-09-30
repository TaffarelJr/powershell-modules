function Install-RequiredModule {
    <#
    .SYNOPSIS
        Installs the required modules that are not already satisfied,
        for the current user.
    .DESCRIPTION
        A module Test-RequiredModule already counts as satisfied is skipped,
        so running this again does not download everything again. Every
        other one is installed without asking, unless given -Confirm, with
        Install-Module's -Scope CurrentUser, -Force and -SkipPublisherCheck:
        the host's trust prompt for the repository is suppressed, and a newer
        version signed by a different publisher than an installed one is
        accepted.

        It installs and returns: it does not look the module up afterwards.
        Assert-RequiredModule reads the manifests, installs through this, and
        then throws if a requirement is still not met.

        -WhatIf and -Confirm name each module that would be installed, with
        its minimum version; a satisfied one is not named.
        With -WhatIf nothing is changed and nothing is returned.

        An install that fails is a terminating error for the call, and in a
        pipeline it stops the pipeline: the modules before it stay installed
        and the ones after it are not tried.

        With -Verbose, shows the Install-Module command before it runs.
    .PARAMETER Module
        One result from Get-RequiredModule, or several, as an array
        or from the pipeline. An empty array installs nothing. A hand-made
        object works too, with a Name that is a plain module name and,
        optionally, a MinimumVersion; without one the newest version is
        installed. Anything else is refused before anything is installed.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Management.Automation.PSCustomObject. A result of
        Get-RequiredModule, with a Name and a MinimumVersion.
    .OUTPUTS
        None. The modules are installed.
    .EXAMPLE
        Get-RequiredModule -Path ./RequiredModules.psd1 | Install-RequiredModule

        Installs whatever the manifest names that is missing or too old.
    .EXAMPLE
        Get-RequiredModule -Path ./RequiredModules.psd1 |
            Install-RequiredModule -WhatIf

        Names each module that would be installed, and installs nothing.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.RequiredModules/README.md
    .LINK
        Assert-RequiredModule
    .LINK
        Test-RequiredModule
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
                if (Test-RequiredModule -Module $item) {
                    continue
                }

                $parameters = Get-ModuleInstallParameter -Module $item
                $target = Get-ModuleRequirementText -Module $item
                if (-not $PSCmdlet.ShouldProcess($target, 'Install module')) {
                    continue
                }

                Write-Verbose "Running $(Get-ModuleInstallCommand -Module $item)"

                # Install-Module reports most failures as non-terminating errors,
                # which this module's own preference does not reach into. Nor do
                # this call's -WhatIf and -Confirm: it would follow the session's,
                # and ask or preview again after the answer above.
                Install-Module @parameters -ErrorAction Stop -WhatIf:$false -Confirm:$false
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
