function Register-GitHubCredentialHelper {
    <#
    .SYNOPSIS
        Configures git to use gh as its credential helper.
    .DESCRIPTION
        By default every host gh is logged in to is configured; gh fails
        if there is none. -Force lets a host gh has no login for be
        configured anyway, and requires -Hostname.
    .PARAMETER Hostname
        Configures only this host.
    .PARAMETER Force
        Configures the host even though gh has no login for it. Only
        with -Hostname.
    #>
    param(
        [string]$Hostname,

        [switch]$Force
    )

    $arguments = @('auth', 'setup-git')
    if ($Hostname) {
        $arguments += @('--hostname', $Hostname)
    }

    if ($Force) {
        $arguments += '--force'
    }

    Invoke-GitHubCommand -Activity 'Configuring git to use gh for credentials' -Arguments $arguments | Out-Null
}
