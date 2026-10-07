using namespace System.IO

function Assert-GitRemoteSource {
    <#
    .SYNOPSIS
        Throws when a remote name is neither a configured remote, nor a URL,
        nor a path that exists, which git would refuse to fetch from or push
        to.
    .DESCRIPTION
        git reads a name it has no remote for as a URL or a path. A configured
        remote, or a name a url.<base>.insteadOf rule rewrites, passes; so
        does anything with a ':' in it, which may be a URL that only the
        network can answer for. Anything else is a path, relative to the
        folder git runs in, and passes only if something exists there.
        Nothing is sent to a remote.
    .PARAMETER Name
        The remote's name, URL or path. A credential a URL in it carries is
        hidden in the message.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed". A
        credential a URL in it carries is hidden in the message.
    .PARAMETER RepoPath
        The folder git runs in. Omit it for PowerShell's current location.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Activity,

        [string]$RepoPath
    )

    $read = Invoke-GitCommand -Activity $Activity -Arguments @('ls-remote', '--get-url', $Name) `
        -RepoPath $RepoPath -Tolerant
    $url = ($read.Output -join '').Trim()
    if ($url -cne $Name -or $Name.Contains(':')) {
        return
    }

    $base = if ($RepoPath) {
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RepoPath)
    }
    else {
        $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
    }

    if (Test-Path -LiteralPath ([Path]::Combine($base, $Name))) {
        return
    }

    $shownActivity = Hide-UrlCredential -Text $Activity
    $shownName = Hide-UrlCredential -Text $Name
    throw "$shownActivity failed: '$shownName' is not a remote, a URL, or a path that exists."
}
