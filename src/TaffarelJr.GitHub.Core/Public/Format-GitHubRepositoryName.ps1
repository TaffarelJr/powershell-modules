function Format-GitHubRepositoryName {
    <#
    .SYNOPSIS
        Returns a repository's name for a person to read - OWNER/REPO, or
        HOST/OWNER/REPO off github.com - with any credential it carried
        removed.
    .DESCRIPTION
        For text a person reads, such as a -WhatIf target or a message: a
        URL a caller gives may carry a token, as in
        https://x-access-token:<token>@github.com/o/r, and none of it may be
        shown.

        The repository is read as ConvertTo-GitHubRepositoryReference reads
        it - OWNER/REPO, HOST/OWNER/REPO, HOST:PORT/OWNER/REPO, an https:,
        http:, ssh:, git:, git+ssh:, or git+https: URL, the SSH form
        git@HOST:OWNER/REPO, or a repository object by its Url, HtmlUrl,
        NameWithOwner, or FullName - and named as
        Assert-GitHubSameRepository names it: OWNER/REPO, with HOST/ in
        front when the host is not github.com. A subdomain of github.com
        (www.github.com) is github.com; a port written in HOST:PORT text
        stays part of the host, and a URL's port is dropped, as gh drops it.
        User info, a query, a fragment, trailing .git and slashes (several
        of each), and anything after OWNER/REPO, such as an issue's path,
        are left out.

        It never throws for what it is given: text that names no repository
        comes back trimmed, with every credential replaced by ***, a query
        or fragment cut off, and trailing .git and slashes dropped, so the
        caller can still show it. An object it cannot read is shown as its
        text, cleaned the same way. What counts as a credential, and what is
        not hidden whole, is Hide-UrlCredential's rule, which does the
        hiding. It errs toward hiding too much: an @ later in the text, such
        as in a path after a credential or after HOST:PORT, hides everything
        up to it too, which leaves the text unreadable as a repository but
        shows no secret.

        Formatting what it returns gives the same text back.
    .PARAMETER Repository
        The repository: OWNER/REPO, HOST/OWNER/REPO, a URL, or a repository
        object - anything Resolve-GitHubRepositoryArgument takes. $null is
        refused by PowerShell, as for any mandatory parameter: a
        -Repository left out leaves nothing to format, and the caller names
        that case itself.
    .INPUTS
        None
    .OUTPUTS
        System.String
        The name to show.
    .EXAMPLE
        Format-GitHubRepositoryName -Repository 'https://x-access-token:ghs_abc@ghe.example.com/o/r.git'

        Returns 'ghe.example.com/o/r'.
    .EXAMPLE
        $name = Format-GitHubRepositoryName -Repository $reference
        $target = "$name issue #$number"

        Names an issue the same way whether its repository was given as
        o/r, as https://github.com/o/r, or as a repository object.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository
    )

    try {
        $ErrorActionPreference = 'Stop'

        $reference = $Repository
        if ($Repository -isnot [string]) {
            # A name to show must never stop the caller: what the converter refuses is shown as text instead.
            try {
                $reference = ConvertTo-GitHubRepositoryReference -Repository $Repository
            }
            catch {
                $reference = $null
            }
            if ($null -eq $reference) {
                $reference = "$Repository"
            }
        }

        $hidden = Hide-UrlCredential -Text $reference
        $text = ($hidden -replace '[?#]\S*', '').Trim() -replace '(?<=[^/])(?:\.git|/(?!(?:\.git)+(?:/|\z)))+\z', ''

        $parts = Split-GitHubRepositoryReference -Reference $text
        if ($null -eq $parts -or "$($parts.Host)$($parts.Owner)$($parts.Name)".Contains('@')) {
            return $text
        }

        $shown = "$($parts.Owner)/$($parts.Name)"
        if ($parts.Host -and $parts.Host -ne 'github.com') {
            $shown = "$($parts.Host)/$shown"
        }

        return $shown
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
