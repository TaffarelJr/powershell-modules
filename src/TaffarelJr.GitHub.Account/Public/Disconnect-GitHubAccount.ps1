function Disconnect-GitHubAccount {
    <#
    .SYNOPSIS
        Removes a stored gh login.
    .DESCRIPTION
        Only the local credential is removed; the token itself is not
        revoked. With more than one account stored, -User (and -Hostname,
        across hosts) is required, since gh cannot prompt for it here.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER User
        The account to log out of (gh's --user). An empty value is
        refused; leave it out for the default.
    .PARAMETER Hostname
        The host to log out of (gh's --hostname). Omit it for gh's default
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
        Disconnect-GitHubAccount -User 'octocat' -Hostname 'ghe.example.com'

        Removes the stored gh login of octocat on ghe.example.com; the token
        itself is not revoked.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/README.md
    .LINK
        Connect-GitHubAccount
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

        $arguments = @('auth', 'logout')
        if ($User) {
            $arguments += @('--user', $User)
        }

        if ($Hostname) {
            $arguments += @('--hostname', $Hostname)
        }

        $account = if ($User) { $User } else { 'the only account' }
        $where = if ($Hostname) { $Hostname } else { "gh's default host" }
        if (-not $PSCmdlet.ShouldProcess("$account on $where", 'Remove gh login')) {
            return
        }

        Invoke-GitHubCommand -Activity 'Logging out' -Argument $arguments | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
