function Disconnect-GitHubAccount {
    <#
    .SYNOPSIS
        Removes a stored gh login.
    .DESCRIPTION
        Only the local credential is removed; the token itself is not
        revoked. With more than one account stored, -User (and -Hostname,
        across hosts) is required, since gh cannot prompt for it here.
    .PARAMETER User
        The account to log out of.
    .PARAMETER Hostname
        The host to log out of. Omit it for gh's default host.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$User,

        [string]$Hostname
    )

    $arguments = @('auth', 'logout')
    if ($User) {
        $arguments += @('--user', $User)
    }

    if ($Hostname) {
        $arguments += @('--hostname', $Hostname)
    }

    Invoke-GitHubCommand -Activity 'Logging out' -Arguments $arguments | Out-Null
}
