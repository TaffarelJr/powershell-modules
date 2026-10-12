function Switch-GitHubAccount {
    <#
    .SYNOPSIS
        Makes another stored account the active one for a host.
    .DESCRIPTION
        With exactly two accounts on the host, gh switches to the other
        one without being told which; with more, -User is required, since
        gh cannot prompt for it here.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER User
        The account to make active (gh's --user). An empty value is
        refused; leave it out for the default.
    .PARAMETER Hostname
        The host to switch on (gh's --hostname). Omit it for gh's default
        host. An empty value is refused; leave it out for the default.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None
    .OUTPUTS
        None
    .EXAMPLE
        Switch-GitHubAccount -User 'octocat' -Hostname 'github.com'

        Makes octocat the active account on github.com.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/README.md
    .LINK
        Get-GitHubAuthStatus
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [ValidateScript({ Assert-GitHubAccountName -User $_ })]
        [string]$User,

        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname
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

        $arguments = @('auth', 'switch')
        if ($User) {
            $arguments += @('--user', $User)
        }

        if ($Hostname) {
            $arguments += @('--hostname', $Hostname)
        }

        $account = if ($User) { $User } else { 'the other account' }
        $where = if ($Hostname) { $Hostname } else { "gh's default host" }
        if (-not $PSCmdlet.ShouldProcess("$account on $where", 'Switch active account')) {
            return
        }

        Invoke-GitHubCommand -Activity 'Switching the active account' -Argument $arguments | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
