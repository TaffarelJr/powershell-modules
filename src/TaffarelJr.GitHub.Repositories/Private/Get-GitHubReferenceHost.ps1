function Get-GitHubReferenceHost {
    <#
    .SYNOPSIS
        Returns the host a repository reference names, or gh's default host
        when it names none.
    .DESCRIPTION
        A URL (https://, ssh://, git://), the SSH form USER@HOST:OWNER/REPO,
        and HOST/OWNER/REPO name a host; OWNER/REPO does not, and gh then
        uses its default host: the one GH_HOST names when it is set, else
        github.com (the same rule TaffarelJr.GitHub.Search compares with).
        A *.github.com host is github.com. A user name, password, or token in
        front of the host (USER:PASSWORD@HOST, TOKEN@HOST/OWNER/REPO) is
        never part of it, so the host can be shown in a message.
    .PARAMETER Reference
        The repository reference, as ConvertTo-GitHubRepositoryReference
        returns it.
    .PARAMETER Named
        Returns nothing, rather than the default host, when the reference
        names no host.
    .OUTPUTS
        The host, lower-cased.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Reference,

        [switch]$Named
    )

    $text = $Reference.Trim()
    $patterns = @(
        '^(?:https?|ssh|git)://(?:[^/]*@)?(?<host>[^/:@]+)'
        '^(?:[^@/:]+@)?(?<host>[^/:@]+):(?!//)[^/]+/[^/]+$'
        '^(?:[^@/:]+@)?(?<host>[^/:@]+)/[^/]+/[^/]+?(?:\.git)?/?$'
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($text, $pattern)
        if ($match.Success) {
            return $match.Groups['host'].Value.ToLowerInvariant() -replace '^(?:[^.]+\.)+github\.com\z', 'github.com'
        }
    }

    if ($Named) {
        return
    }

    $default = 'github.com'
    if (-not [string]::IsNullOrWhiteSpace($env:GH_HOST)) {
        $default = $env:GH_HOST.Trim().ToLowerInvariant() -replace '^(?:[^.]+\.)+github\.com\z', 'github.com'
    }

    return $default
}
