using namespace System.Collections

function Resolve-GitHubItemReference {
    <#
    .SYNOPSIS
        Returns the number, URL, or branch name gh takes for an issue or a
        pull request, from any of those or from an object.
    .DESCRIPTION
        One resolver for both kinds, since gh's issue and pr commands read
        their operand the same way:

        - A number, 7 or '#7', is returned as its digits. Only 1 to 10
          ASCII digits count, so a full-width or Arabic-Indic digit, or a
          number too long for gh, is refused here rather than by gh, and
          so is 0.
        - A URL must name an item of the kind asked for -
          .../OWNER/REPO/issues/N for an issue, .../OWNER/REPO/pull/N for a
          pull request - and may carry a trailing path, query, or fragment
          (/files, #issuecomment-1). One naming the other kind throws,
          pointing at the module for it: gh's issue commands would quietly
          act on a pull request.
        - For a pull request, any other text that does not start with a
          dash, hold whitespace, or consist of digits is a branch name
          (OWNER:BRANCH included).
        - An object - a listing's, a search result's, a raw API response's,
          or a hashtable - is read by its HtmlUrl (html_url), then by its
          Url when that is the web URL of an item of this kind (a raw API
          object's url is the REST one, and is passed over), then by its
          Number, which must be a whole number: anything else there is
          refused, never read as a branch name. An IsPullRequest that says
          it is the other kind throws.

        A value that starts with a dash never reaches gh, so this doubles
        as the guard against option injection. An array of one item is
        read as that item, so an array holding only $null is the $null
        below. A bool, a longer or empty array (one item per call - see
        -NotPiped), and a $null that was given all
        throw: a caller with an optional item calls this only when one was
        given, so a lookup that came back empty cannot silently mean "the
        current branch's".

        With -Repository, a URL naming a different repository throws, as
        Assert-GitHubSameRepository compares them: gh would follow the URL
        and ignore -Repository.
    .PARAMETER Item
        The issue or pull request: a number, a URL, a branch name (pull
        requests only), or an object.
    .PARAMETER Kind
        Issue or PullRequest.
    .PARAMETER Repository
        The repository the caller will pass to gh as --repo, in
        [HOST/]OWNER/REPO or URL form or as a repository object, to check a
        URL against. $null or an empty string checks nothing.
    .PARAMETER NotPiped
        Says the caller's parameter cannot be piped (Close-GitHubIssue
        -DuplicateOf, say), so a list is refused with "call once per issue"
        instead of "pipe them to name several".
    .INPUTS
        None
    .OUTPUTS
        System.String
        The operand for gh: the digits, the URL as given, or the branch
        name.
    .EXAMPLE
        $operand = Resolve-GitHubItemReference -Item $InputObject `
            -Kind PullRequest -Repository $Repository

        Gives 'https://github.com/o/r/pull/7' for a listing object of that
        pull request, '7' for 7 or '#7', and 'feature/x' for that branch.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Item,

        [Parameter(Mandatory)]
        [ValidateSet('Issue', 'PullRequest')]
        [string]$Kind,

        [AllowNull()]
        [object]$Repository,

        [switch]$NotPiped
    )

    try {
        $ErrorActionPreference = 'Stop'

        $kinds = @{
            Issue       = @{
                Noun     = 'issue'
                Name     = 'an issue'
                Title    = 'An issue'
                Segment  = 'issues'
                Module   = 'TaffarelJr.GitHub.Issues'
                Accepted = 'its number or URL, or an issue object'
            }
            PullRequest = @{
                Noun     = 'pull request'
                Name     = 'a pull request'
                Title    = 'A pull request'
                Segment  = 'pull'
                Module   = 'TaffarelJr.GitHub.PullRequests'
                Accepted = 'its number, URL, or branch name, or a pull request object'
            }
        }
        $asked = $kinds[$Kind]
        $other = if ($Kind -eq 'Issue') { $kinds.PullRequest } else { $kinds.Issue }
        $wrongKind = "use $($other.Module) for it."

        if ($Item -isnot [string] -and $Item -isnot [IDictionary] -and $Item -is [IEnumerable]) {
            $items = @($Item)
            if ($items.Count -eq 0) {
                throw "Give one $($asked.Noun), not an empty list."
            }

            if ($items.Count -eq 1) {
                $Item = $items[0]
            }
        }

        if ($null -eq $Item) {
            $hint = ''
            if ($Kind -eq 'PullRequest') {
                $hint = " - leave it out to use the current branch's pull request"
            }

            throw "$($asked.Title) was given, but it is `$null$hint."
        }

        $refusal = "is not $($asked.Name): give $($asked.Accepted)."
        if ($Item -is [bool] -or $Item -is [System.Management.Automation.SwitchParameter]) {
            throw "'$Item' $refusal"
        }

        if ($Item -isnot [string] -and $Item -isnot [IDictionary] -and $Item -is [IEnumerable]) {
            $advice = if ($NotPiped) { "call once per $($asked.Noun)" } else { 'pipe them to name several' }
            throw "Give one $($asked.Noun) at a time, not a list of $(@($Item).Count); $advice."
        }

        $repositoryPart = '^https?://(?<host>[^/\s]+)/(?<owner>[^/\s]+)/(?<repo>[^/\s]+)'
        $urlPattern = $repositoryPart + '/(?<kind>issues|pull)/[0-9]+(?:[/?#]\S*)?$'
        $reference = $Item
        if ($Item -isnot [string] -and $Item -isnot [ValueType]) {
            $values = @{}
            if ($Item -is [IDictionary]) {
                foreach ($key in $Item.PSBase.Keys) {
                    $values["$key"] = $Item[$key]
                }
            }
            else {
                foreach ($property in $Item.PSObject.Properties) {
                    $values[$property.Name] = $property.Value
                }
            }

            $isPullRequest = $values['IsPullRequest']
            if ($null -ne $isPullRequest -and [bool]$isPullRequest -ne ($Kind -eq 'PullRequest')) {
                throw "This object is $($other.Name), not $($asked.Name): $wrongKind"
            }

            $url = "$($values['Url'])"
            $reference = $values['HtmlUrl']
            if (-not $reference) {
                $reference = $values['html_url']
            }

            if (-not $reference -and $url -match $urlPattern) {
                $reference = $url
            }

            if (-not $reference) {
                $number = $values['Number']
                if ($null -eq $number) {
                    throw "$($asked.Title) object needs an HtmlUrl, a Url, or a Number, and this one has none:" +
                    " $($Item.GetType().Name)."
                }

                $reference = "$number".Trim()
                if ($reference -notmatch '^[0-9]{1,10}\z') {
                    $shown = Hide-UrlCredential -Text $reference
                    throw "'$shown' is not $($asked.Name) number: an object's Number must be a whole number" +
                    ' of 1 to 10 digits.'
                }
            }
        }

        $text = "$reference".Trim()
        $shown = Hide-UrlCredential -Text $text
        if ($text -match '^#?(?<number>[0-9]{1,10})$') {
            $number = $Matches['number']
            if ([long]$number -lt 1) {
                throw "'$shown' is not $($asked.Name): numbers start at 1."
            }

            return $number
        }

        if ($text -match '^https?://') {
            if ($text -notmatch $urlPattern) {
                throw "'$shown' is not $($asked.Name): a URL must end in /OWNER/REPO/$($asked.Segment)/NUMBER."
            }

            if ($Matches['kind'] -ne $asked.Segment) {
                throw "'$shown' is $($other.Name), not $($asked.Name): $wrongKind"
            }

            if ($Repository) {
                Assert-GitHubSameRepository -Item "'$text'" -Origin $text -Repository $Repository
            }

            return $text
        }

        # \d is any Unicode digit, so a number gh cannot read is never taken for a branch name.
        if ($Kind -eq 'PullRequest' -and $text -match '^(?!-)\S+$' -and $text -notmatch '^#?\d+$') {
            return $text
        }

        throw "'$shown' $refusal"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
