function Get-GitHubAuthStatus {
    <#
    .SYNOPSIS
        Returns every account gh knows about, with its host and whether
        it is the active one there.
    .DESCRIPTION
        gh reports its accounts grouped under each host; this flattens
        them into one object per account, each carrying its Host, so a
        caller can filter on either without walking a nested map.
    .PARAMETER Hostname
        Reports only this host's accounts.
    .PARAMETER Active
        Reports only the active account on each host.
    .PARAMETER ShowToken
        Includes each account's token in plain text.
    .OUTPUTS
        One object per account - Host, Login, Active, State, TokenSource,
        GitProtocol, Scopes, and Token with -ShowToken - always an array.
    #>
    param(
        [string]$Hostname,

        [switch]$Active,

        [switch]$ShowToken
    )

    $arguments = @('auth', 'status', '--json', 'hosts', '--jq', '.hosts | add // []')
    if ($Hostname) {
        $arguments += @('--hostname', $Hostname)
    }

    if ($Active) {
        $arguments += '--active'
    }

    if ($ShowToken) {
        $arguments += '--show-token'
    }

    $out = Invoke-GitHubCommand -Activity 'Reading authentication status' -Arguments $arguments
    $accounts = ConvertFrom-GitHubJson -Lines $out
    return , @($accounts)
}
