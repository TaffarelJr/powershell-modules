function Split-GitHubRepositoryReference {
    <#
    .SYNOPSIS
        Returns the host, owner, and name a repository reference or URL
        names, or nothing when it cannot be read as one.
    .DESCRIPTION
        Not exported. What gh reads as a URL (Test-GitHubUrlText) is read
        as one: a web URL (https://HOST/OWNER/REPO, with anything after it -
        an item's own path, a query, a fragment), an ssh://, git://,
        git+ssh://, or git+https:// URL, and the SSH form
        git@HOST:OWNER/REPO; a URL's port is dropped, as gh drops it, and
        the user information of a URL or of the SSH form is skipped up to
        the last @ before the host, a password's own @ included, as gh
        does. Other
        text is read as HOST/OWNER/REPO or OWNER/REPO, where gh keeps a
        port as part of the host (ghe.example.com:8443). A trailing .git
        or slash is dropped. A subdomain of github.com (www.github.com) is
        github.com, as gh reads it. A bare REPO, a form with more parts than
        these, other text holding @ or a scheme gh does not know (GIT@...,
        HTTPS://...), and a REST URL (https://api.HOST/repos/... or
        https://HOST/api/v3/repos/...), which names no web page, give
        nothing: gh cannot read those as a repository either.
    .PARAMETER Reference
        The reference or URL.
    .OUTPUTS
        A hashtable with Host ($null when the reference gives none), Owner,
        and Name; nothing when the reference cannot be read.
    #>
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Reference
    )

    $text = $Reference.Trim()
    if ($text -match '^https?://(?:api\.[^/\s]+/repos|[^/\s]+/api/v3)/') {
        return
    }

    $repository = '(?<owner>[^/\s:]+)/(?<name>[^/\s]+?)(?:\.git)?'
    $forms = @(
        "^(?<host>[^/:@\s]+(?::[0-9]+)?)/$repository/?\z"
        "^$repository/?\z"
    )
    if (Test-GitHubUrlText -Text $text) {
        $forms = @(
            # The user information runs to the last @ before the first /, ? or #, so a password may hold an @.
            "^(?:https?|ssh|git|git\+ssh|git\+https)://(?:[^/?#\s]*@)?(?<host>[^/:@\s]+)(?::[0-9]+)?/$repository" +
            '(?:[/?#]\S*)?\z'
            # gh reads everything between the first colon and the last slash as the owner, colons included.
            "^git@(?:[^/:\s]*@)?(?<host>[^/:@\s]+):(?<owner>[^/\s]+)/(?<name>[^/\s]+?)(?:\.git)?/?\z"
        )
    }

    foreach ($form in $forms) {
        if ($text -match $form) {
            $parts = @{
                Host  = $Matches['host']
                Owner = $Matches['owner']
                Name  = $Matches['name']
            }
            if ($parts.Host -match '^(?:[^.]+\.)+github\.com\z') {
                $parts.Host = 'github.com'
            }

            return $parts
        }
    }
}
