using namespace System.Collections

function ConvertTo-GitHubRepositoryReference {
    <#
    .SYNOPSIS
        Returns the OWNER/REPO, HOST/OWNER/REPO, or URL gh takes for a
        repository, from any of those or from a repository object.
    .DESCRIPTION
        An object - a repository listing's, a search result's, a raw API
        response's, or a hashtable - is read by its Url first, which
        carries the host and so finds the repository on GitHub Enterprise
        too, then by its HtmlUrl (html_url), then by its NameWithOwner,
        then by its FullName (full_name); an empty or blank one is passed
        over for the next. A Url or HtmlUrl counts only when it is a
        repository's web URL, https://HOST/OWNER/REPO: a raw API object's
        url is the REST one (https://api.github.com/repos/OWNER/REPO), and
        an issue's or pull request's is the item's own, and gh can use
        neither as a repository. A hashtable is read by those keys, in any
        case.

        In the text forms OWNER/REPO, HOST/OWNER/REPO, and
        HOST:PORT/OWNER/REPO a trailing .git and trailing slashes are
        dropped: gh would read o/r.git as a repository named r.git, which
        GitHub never allows, and refuses o/r/. What gh parses as a URL - a
        scheme it knows (https:, http:, ssh:, git:, git+ssh:, git+https:)
        or the SSH form git@HOST:OWNER/REPO, each matched with case, as gh
        does - is returned as it is, since gh drops its .git itself. Any
        other USER@HOST:OWNER/REPO (GIT@ included) is refused, as gh cannot
        read it; HTTPS://... is plain text, which gh refuses in turn.

        Anything that starts with a dash or holds whitespace throws, so a
        value gh would read as an option never reaches it. An array of one
        repository is read as that repository; an empty array, or more
        than one repository at a time, throws: the caller calls once per
        repository.

        $null returns nothing, for a repository left to gh to find from
        the current directory, and so does an array holding only $null:
        telling a -Repository given as $null from one left out is
        Resolve-GitHubRepositoryArgument's job, which refuses both.

        A parameter that takes both a value and an object by pipeline must
        be an [object]: as a [string], PowerShell turns a piped object into
        its text ("@{Name=...}") instead of reading it.
    .PARAMETER Repository
        A repository as OWNER/REPO, HOST/OWNER/REPO, or a URL, or a
        repository object. A blank one throws "-<Name> is blank: give
        OWNER/REPO, HOST/OWNER/REPO, or a URL."
    .PARAMETER Name
        The caller's parameter, without its dash, for the messages that
        name it (blank, empty list, and a list, where it is added as "for
        -<Name>" unless it is Repository). Repository when left out.
    .INPUTS
        None
    .OUTPUTS
        System.String
        The reference; nothing for $null.
    .EXAMPLE
        $reference = ConvertTo-GitHubRepositoryReference -Repository $repository

        Gives 'https://ghe.example.com/o/r' for an object whose Url is
        that, and 'o/r' for the text 'o/r'.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Repository,

        [ValidatePattern('^\w+\z', ErrorMessage = "'{0}' is not a parameter name: give it without its dash.")]
        [string]$Name = 'Repository'
    )

    try {
        $ErrorActionPreference = 'Stop'

        if ($null -eq $Repository) {
            return
        }

        if ($Repository -isnot [string] -and $Repository -isnot [IDictionary] -and $Repository -is [IEnumerable]) {
            $items = @($Repository)
            if ($items.Count -eq 0) {
                throw "-$Name is an empty list: give one repository, or leave it out."
            }

            if ($items.Count -gt 1) {
                $where = if ($Name -ne 'Repository') { " for -$Name" } else { '' }
                throw "Give one repository at a time$where, not a list of $($items.Count); call once per repository."
            }

            $Repository = $items[0]
            if ($null -eq $Repository) {
                return
            }
        }

        $reference = $Repository
        if ($Repository -isnot [string]) {
            $values = @{}
            if ($Repository -is [IDictionary]) {
                foreach ($key in $Repository.PSBase.Keys) {
                    $values["$key"] = $Repository[$key]
                }
            }
            else {
                foreach ($property in $Repository.PSObject.Properties) {
                    $values[$property.Name] = $property.Value
                }
            }

            $webUrl = '^https?://[^/\s]+/[^/\s]+/[^/\s]+?(?:\.git)?/?\z'
            $reference = $null
            foreach ($name in 'Url', 'HtmlUrl', 'html_url', 'NameWithOwner', 'FullName', 'full_name') {
                $value = $values[$name]
                if ([string]::IsNullOrWhiteSpace("$value") -or ($name -like '*url' -and "$value" -notmatch $webUrl)) {
                    continue
                }

                $reference = $value
                break
            }

            if ($null -eq $reference) {
                throw "A repository object needs a repository's web URL in its Url or HtmlUrl, a NameWithOwner," +
                " or a FullName, and this one has none: $($Repository.GetType().Name)."
            }
        }

        $text = "$reference".Trim()
        if (-not $text) {
            throw "-$Name is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
        }

        if ($text -match '^(?!-)\S+$') {
            # gh reads OWNER/REPO.git as a repository named REPO.git, and refuses a trailing slash. What gh
            # parses as a URL - a scheme it knows, or git@HOST:OWNER/REPO - keeps its text; gh strips that itself.
            $isUrl = Test-GitHubUrlText -Text $text
            if (-not $isUrl -and $text -match '^[^/@]+@[^/]*:') {
                $shown = Hide-UrlCredential -Text $text
                throw "'$shown' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
            }
            if (-not $isUrl -and $text -match '^(?<path>(?:[^/]+/)?[^/]+/[^/]+?)(?:\.git)?/*\z') {
                $text = $Matches['path']
            }

            return $text
        }

        $shown = Hide-UrlCredential -Text $text
        throw "'$shown' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
