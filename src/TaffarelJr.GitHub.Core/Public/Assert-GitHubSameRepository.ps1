function Assert-GitHubSameRepository {
    <#
    .SYNOPSIS
        Throws when an item comes from a different repository from the one
        -Repository names.
    .DESCRIPTION
        gh follows a URL's own repository and ignores --repo, and an object
        listed from one repository acted on in another is the wrong item,
        so a caller who gave both an item and -Repository is told when
        they disagree rather than having one of them quietly win.

        Both sides are read as gh reads them: a URL - https:, http:, ssh:,
        git:, git+ssh:, git+https: (with or without an item's own path
        after the repository), or git@HOST:OWNER/REPO, prefixes matched with
        case - whose port is ignored, or HOST[:PORT]/OWNER/REPO text, whose
        port is part of the host, or OWNER/REPO; a trailing .git or slash
        is ignored, and a subdomain of github.com is github.com, as gh
        reads it. Owner and name are compared without case, as GitHub
        does. The host is compared only when both sides give one: OWNER/REPO
        leaves the host to gh. A side that cannot be read that way - a bare
        REPO, other text holding @ (GIT@... included), or a REST URL such as
        https://api.github.com/repos/OWNER/REPO - is not comparable and is
        left for gh to judge.
    .PARAMETER Item
        What the item is, as the message should name it - such as
        "'https://github.com/o/r/issues/7'" or 'Release v1'.
    .PARAMETER Origin
        The repository the item comes from: its URL, a repository's URL, or
        a reference.
    .PARAMETER Repository
        The repository -Repository names: its text, as resolved by
        ConvertTo-GitHubRepositoryReference, or a repository object, which
        is read as that function reads it. A blank one throws.
    .PARAMETER PassThru
        Returns the repository to act on: -Repository as given, except when
        only the item's side names a host, which then gives HOST/OWNER/REPO
        from the item - so an item from GitHub Enterprise stays there.
    .INPUTS
        None
    .OUTPUTS
        System.String
        With -PassThru, the repository reference to act on; without it,
        nothing.
    .EXAMPLE
        Assert-GitHubSameRepository -Item "Release $tag" `
            -Origin $release.Repository -Repository $reference

        Throws "Release v1 is in a/b, but -Repository names c/d: give one or
        the other." when the release was listed from a/b.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Item,

        [Parameter(Mandatory)]
        [string]$Origin,

        [Parameter(Mandatory)]
        [object]$Repository,

        [switch]$PassThru
    )

    try {
        $ErrorActionPreference = 'Stop'

        $given = if ($Repository -is [string] -and $Repository.Trim()) {
            $Repository.Trim()
        }
        else {
            ConvertTo-GitHubRepositoryReference -Repository $Repository
        }

        if (-not $given) {
            throw '-Repository holds only $null: give OWNER/REPO, HOST/OWNER/REPO, or a URL.'
        }

        $from = Split-GitHubRepositoryReference -Reference $Origin
        $named = Split-GitHubRepositoryReference -Reference $given
        if ($null -eq $from -or $null -eq $named) {
            if ($PassThru) {
                return $given
            }

            return
        }

        $ignoreCase = [StringComparison]::OrdinalIgnoreCase
        $bothHosts = $from.Host -and $named.Host
        $sameHost = -not $bothHosts -or [string]::Equals($from.Host, $named.Host, $ignoreCase)
        $sameOwner = [string]::Equals($from.Owner, $named.Owner, $ignoreCase)
        $sameName = [string]::Equals($from.Name, $named.Name, $ignoreCase)
        if (-not ($sameHost -and $sameOwner -and $sameName)) {
            $shown = "$($from.Owner)/$($from.Name)"
            if ($bothHosts -or ($from.Host -and $from.Host -ne 'github.com')) {
                $shown = "$($from.Host)/$shown"
            }

            $shownItem = Hide-UrlCredential -Text $Item
            $shownGiven = Hide-UrlCredential -Text $given
            throw "$shownItem is in $shown, but -Repository names ${shownGiven}: give one or the other."
        }

        if (-not $PassThru) {
            return
        }

        if ($from.Host -and -not $named.Host) {
            return "$($from.Host)/$($from.Owner)/$($from.Name)"
        }

        return $given
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
