function ConvertTo-GitHubSearchRepository {
    <#
    .SYNOPSIS
        Returns the OWNER/REPO gh's search takes for a repository, from
        text or from a repository object.
    .DESCRIPTION
        gh search sends --repo to GitHub word for word as a repo:
        qualifier, on its default host - the one GH_HOST names, else the
        one host gh is logged in to, else github.com - so only OWNER/REPO
        finds anything. A named host is compared with GH_HOST when it is
        set and with github.com when it is not, so someone logged in only
        to an Enterprise host sets GH_HOST.

        The reference is read as TaffarelJr.GitHub.Core reads one. A
        repository object goes through ConvertTo-GitHubRepositoryReference.
        Text gh reads as a URL - starting git@, https:, http:, ssh:, git:,
        git+ssh:, or git+https:, matched with case, as gh matches it - is
        a URL, with anything after OWNER/REPO (an item's path, a query, a
        fragment) and the URL's port dropped, or the SSH form
        git@HOST:OWNER/REPO, whose owner runs from the first colon to the
        last slash, as gh reads it. Other text is HOST/OWNER/REPO or
        OWNER/REPO, where a port stays part of the host
        (ghe.example.com:8443), as gh keeps it. A trailing .git or slash
        is dropped, and a subdomain of github.com, such as www.github.com,
        is github.com.

        A repository on another host throws, saying what it was compared
        with and how to change it, and so does text that names no
        repository: a bare name, a REST URL (api.HOST/repos/... or
        HOST/api/v3/repos/...), a scheme gh does not know (HTTPS://...),
        git@HOST:PORT/OWNER/REPO or git@HOST/OWNER/REPO, and
        USER@HOST:OWNER/REPO with a user other than git (GIT@ included),
        none of which gh can read.
    .PARAMETER Repository
        A repository as OWNER/REPO, HOST/OWNER/REPO, a URL, the SSH form,
        or a repository object.
    .OUTPUTS
        The OWNER/REPO.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Repository
    )

    $reference = ConvertTo-GitHubRepositoryReference -Repository $Repository
    $shown = Hide-UrlCredential -Text $reference
    $notRepository = "'$shown' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
    if ($reference -match '^(?:[a-z+]+://)?(?:api\.[^/\s]+/repos|[^/\s]+/api/v3/repos)/') {
        throw $notRepository
    }

    $repository = '(?<owner>[^/\s:]+)/(?<name>[^/\s]+?)(?:\.git)?'
    $forms = @(
        "^(?<host>[^/:@\s]+(?::[0-9]+)?)/$repository/?\z"
        "^$repository/?\z"
    )
    if ($reference -cmatch '^(?:git@|(?:https?|ssh|git|git\+ssh|git\+https):)') {
        $forms = @(
            "^(?:https?|ssh|git|git\+ssh|git\+https)://(?:[^@/\s]+@)?(?<host>[^/:\s]+)(?::[0-9]+)?/$repository" +
            '(?:[/?#]\S*)?\z'
            "^git@(?<host>[^/:\s]+):(?<owner>[^/\s]+)/(?<name>[^/\s]+?)(?:\.git)?/?\z"
        )
    }

    $searched = 'github.com'
    $why = 'GH_HOST is not set, so it is compared with github.com'
    if (-not [string]::IsNullOrWhiteSpace($env:GH_HOST)) {
        $searched = $env:GH_HOST.Trim() -replace '^(?:[^.]+\.)+github\.com\z', 'github.com'
        $shownSearched = Hide-UrlCredential -Text $searched
        $why = "GH_HOST names $shownSearched"
    }

    foreach ($form in $forms) {
        if ($reference -notmatch $form) {
            continue
        }

        $hostName = $Matches['host'] -replace '^(?:[^.]+\.)+github\.com\z', 'github.com'
        # An authority with a second @ puts the end of its user information in the host.
        if ($hostName -like '*@*') {
            throw $notRepository
        }

        if ($hostName -and -not [string]::Equals($hostName, $searched, 'OrdinalIgnoreCase')) {
            throw "'$shown' is on $hostName, but $why`: set GH_HOST to $hostName to search there."
        }

        return "$($Matches['owner'])/$($Matches['name'])"
    }

    throw $notRepository
}
