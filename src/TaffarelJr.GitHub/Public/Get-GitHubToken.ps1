function Get-GitHubToken {
    <#
    .SYNOPSIS
        Returns the stored authentication token for an account.
    .DESCRIPTION
        For handing gh's own credential to something that is not gh - a
        git remote URL, a REST call from Invoke-RestMethod. Treat the
        result as a secret: never write it to a log or a console.
    .PARAMETER Hostname
        The host whose token to return. Omit it for gh's default host.
    .PARAMETER User
        The account whose token to return. Omit it for the host's active
        account.
    .OUTPUTS
        The token, as a string.
    #>
    param(
        [string]$Hostname,

        [string]$User
    )

    $arguments = @('auth', 'token')
    if ($Hostname) {
        $arguments += @('--hostname', $Hostname)
    }

    if ($User) {
        $arguments += @('--user', $User)
    }

    $out = Invoke-GitHubCommand -Activity 'Reading the authentication token' -Arguments $arguments
    return $out[0]
}
