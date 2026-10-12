function Connect-GitHubAccount {
    <#
    .SYNOPSIS
        Stores a token as a gh login for a host.
    .DESCRIPTION
        The token travels to gh on standard input, never as an argument,
        so it cannot appear in a failure message. gh's browser-based
        login flow needs an interactive terminal and is not offered here;
        for a headless job, setting GH_TOKEN in the environment is simpler
        still and needs no login at all.
    .PARAMETER Token
        A personal access token with at least the repo, read:org, and
        gist scopes.
    .PARAMETER Hostname
        The host to log in to. Omit it for github.com.
    .PARAMETER GitProtocol
        The protocol gh configures git to use for this host: ssh or
        https.
    .PARAMETER Scopes
        Additional scopes to request beyond gh's minimum.
    .PARAMETER InsecureStorage
        Stores the token in a plain text file instead of the system
        credential store.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Token,

        [string]$Hostname,

        [ValidateSet('ssh', 'https')]
        [string]$GitProtocol,

        [string[]]$Scopes,

        [switch]$InsecureStorage
    )

    $arguments = @('auth', 'login', '--with-token')
    if ($Hostname) {
        $arguments += @('--hostname', $Hostname)
    }

    if ($GitProtocol) {
        $arguments += @('--git-protocol', $GitProtocol)
    }

    foreach ($scope in $Scopes) {
        $arguments += @('--scopes', $scope)
    }

    if ($InsecureStorage) {
        $arguments += '--insecure-storage'
    }

    Invoke-GitHubCommand -Activity 'Logging in' -Arguments $arguments -StdIn $Token | Out-Null
}
