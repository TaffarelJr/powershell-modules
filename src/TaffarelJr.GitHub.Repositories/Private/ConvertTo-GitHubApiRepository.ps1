function ConvertTo-GitHubApiRepository {
    <#
    .SYNOPSIS
        Returns the OWNER/REPO part of a REST API path, and the host to
        send it to, for a repository given any way gh takes one.
    .DESCRIPTION
        The REST API wants the repository inside the endpoint's path, and
        its host apart, as gh api's --hostname. A reference is read as
        ConvertTo-GitHubRepositoryReference reads it, then split:
        OWNER/REPO, HOST/OWNER/REPO, or https://HOST/OWNER/REPO (a .git
        ending and a trailing slash are dropped). OWNER and REPO must be
        letters, digits, '.', '_', or '-', so a value cannot reach another
        endpoint through the path. A host with a port is refused, as
        Invoke-GitHubApi refuses one for its -Hostname.

        A host in the reference and -Hostname must agree. Neither, and the
        path is gh's own {owner}/{repo}, filled in from the current
        directory's repository.
    .PARAMETER Repository
        The repository, or $null for the current directory's.
    .PARAMETER Hostname
        The host the caller named, if any.
    .OUTPUTS
        An object with Path (OWNER/REPO, or {owner}/{repo}) and Hostname
        (the host, or $null for gh's default).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [AllowNull()]
        [object]$Repository,

        [AllowEmptyString()]
        [string]$Hostname
    )

    $reference = ConvertTo-GitHubRepositoryReference -Repository $Repository
    $path = '{owner}/{repo}'
    $server = $null
    if ($reference) {
        $segment = '[A-Za-z0-9._-]+'
        $pattern = '^(?:(?:https?://)?(?<server>(?!-)[\p{L}\p{N}._-]+)(?::(?<port>[0-9]*))?/)?' +
        "(?<owner>$segment)/(?<name>${segment}?)(?:\.git)?/?\z"
        $matched = $reference -match $pattern
        if (-not $matched -or $Matches['owner'] -in '.', '..' -or $Matches['name'] -in '.', '..') {
            $shown = Hide-UrlCredential -Text $reference
            throw "'$shown' is not a repository the API can be asked about: give OWNER/REPO," +
            ' HOST/OWNER/REPO, or https://HOST/OWNER/REPO.'
        }

        if ($Matches.ContainsKey('port')) {
            throw "'$reference' names a port, which gh api cannot be given: give the host without one."
        }

        $path = "$($Matches['owner'])/$($Matches['name'])"
        $server = $Matches['server']
    }

    if ($Hostname -and $server -and $Hostname -ne $server) {
        throw "'$reference' is on $server, but -Hostname names ${Hostname}: give one or the other."
    }

    if ($Hostname) {
        $server = $Hostname
    }

    return [PSCustomObject]@{
        Path     = $path
        Hostname = $server
    }
}
