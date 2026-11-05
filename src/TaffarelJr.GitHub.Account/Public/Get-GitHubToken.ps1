function Get-GitHubToken {
    <#
    .SYNOPSIS
        Returns the stored authentication token for an account.
    .DESCRIPTION
        For handing gh's own credential to something that is not gh - a
        git remote URL, a REST call from Invoke-RestMethod. Treat the
        result as a secret: never write it to a log or a console.
    .PARAMETER User
        The account whose token to return (gh's --user). Omit it for the
        host's active account. An empty value is refused; leave it out for
        the default.
    .PARAMETER Hostname
        The host whose token to return (gh's --hostname). Omit it for gh's
        default host. An empty value is refused; leave it out for the
        default.
    .INPUTS
        None
    .OUTPUTS
        System.String
        The token.
    .EXAMPLE
        $headers = @{ Authorization = "Bearer $(Get-GitHubToken)" }
        Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers

        Calls GitHub's API with gh's own login, without the token ever
        reaching the console.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/README.md
    .LINK
        Get-GitHubAuthStatus
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [ValidateScript({ Assert-GitHubAccountName -User $_ })]
        [string]$User,

        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $arguments = @('auth', 'token')
        if ($Hostname) {
            $arguments += @('--hostname', $Hostname)
        }

        if ($User) {
            $arguments += @('--user', $User)
        }

        $out = @(Invoke-GitHubCommand -Activity 'Reading the authentication token' -Argument $arguments)
        if ($out.Count -eq 0) {
            throw 'Reading the authentication token failed: gh exited 0 but printed no token.'
        }

        return $out[0]
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
