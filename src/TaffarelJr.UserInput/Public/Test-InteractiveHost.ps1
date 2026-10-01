function Test-InteractiveHost {
    <#
    .SYNOPSIS
        Reports whether this session can prompt a person,
        as opposed to running unattended in CI.
    .DESCRIPTION
        Checked in this order: a CI environment variable wins outright
        (a real terminal attached to a CI runner is still not a person to prompt),
        then the -NonInteractive launch flag,
        then whether the host reports a user is actually present.
    #>
    if ($env:CI -or $env:GITHUB_ACTIONS) {
        return $false
    }

    if ([Environment]::GetCommandLineArgs() -contains '-NonInteractive') {
        return $false
    }

    return [Environment]::UserInteractive
}
