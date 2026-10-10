function Switch-GitHubAccount {
    <#
    .SYNOPSIS
        Makes another stored account the active one for a host.
    .DESCRIPTION
        With exactly two accounts on the host, gh switches to the other
        one without being told which; with more, -User is required, since
        gh cannot prompt for it here.
    .PARAMETER User
        The account to make active.
    .PARAMETER Hostname
        The host to switch on. Omit it for gh's default host.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$User,

        [string]$Hostname
    )

    $arguments = @('auth', 'switch')
    if ($User) {
        $arguments += @('--user', $User)
    }

    if ($Hostname) {
        $arguments += @('--hostname', $Hostname)
    }

    Invoke-GitHubCommand -Activity 'Switching the active account' -Arguments $arguments | Out-Null
}
