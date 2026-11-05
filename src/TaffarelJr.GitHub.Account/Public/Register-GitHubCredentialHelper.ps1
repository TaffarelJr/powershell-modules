function Register-GitHubCredentialHelper {
    <#
    .SYNOPSIS
        Configures git to use gh as its credential helper.
    .DESCRIPTION
        By default every host gh is logged in to is configured; gh fails
        if there is none. -Force lets a host gh has no login for be
        configured anyway, and so needs -Hostname: given -Force alone,
        PowerShell asks for the host, or throws where it cannot ask.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Hostname
        Configures only this host (gh's --hostname). An empty value is
        refused; leave it out for the default, every host gh is logged in
        to.
    .PARAMETER Force
        Configures the host even though gh has no login for it. Only
        with -Hostname.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None
    .OUTPUTS
        None
    .EXAMPLE
        Register-GitHubCredentialHelper

        Configures git to ask gh for the credentials of every host gh is
        logged in to.
    .EXAMPLE
        Register-GitHubCredentialHelper -Hostname 'ghe.example.com' -Force

        Configures git for ghe.example.com, even though gh has no login for
        it yet.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/README.md
    #>
    [CmdletBinding(DefaultParameterSetName = 'EveryHost', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'OneHost')]
        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname,

        [Parameter(ParameterSetName = 'OneHost')]
        [switch]$Force
    )

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

        $arguments = @('auth', 'setup-git')
        if ($Hostname) {
            $arguments += @('--hostname', $Hostname)
        }

        if ($Force) {
            $arguments += '--force'
        }

        $target = if ($Hostname) { $Hostname } else { 'every host gh is logged in to' }
        if (-not $PSCmdlet.ShouldProcess($target, 'Configure git to use gh for credentials')) {
            return
        }

        Invoke-GitHubCommand -Activity 'Configuring git to use gh for credentials' -Argument $arguments | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
