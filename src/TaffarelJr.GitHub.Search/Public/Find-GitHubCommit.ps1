function Find-GitHubCommit {
    <#
    .SYNOPSIS
        Searches GitHub for commits.
    .DESCRIPTION
        Give a query, a filter, or both: with neither the search would
        cover all of GitHub, so that throws. A filter that is passed but
        empty or blank throws for the same reason, rather than being left
        out. A list value holding a comma throws too, as gh would split it
        into two filters: give each value on its own, and put a
        qualifier whose one value holds a comma in -Query, quoted
        (label:"a,b").
    .PARAMETER Query
        Search keywords, each one a separate value, or none to rely on the
        filters alone. A value with a space in it is searched as an exact
        phrase, so 'fix typo' is one phrase where 'fix', 'typo' is two
        keywords. A qualifier such as merge:true is a value of its own, and
        one starting with a dash excludes (-author:bot).
    .PARAMETER Owner
        Only commits in repositories owned by one of these users or
        organizations.
    .PARAMETER Repository
        Only commits in one of these repositories, each as OWNER/REPO,
        a URL, HOST/OWNER/REPO, or a repository object such as another
        search result's Repository; gh is given its OWNER/REPO. gh
        searches its default host - the one GH_HOST names, else the one
        host gh is logged in to, else github.com. A named host is
        compared with GH_HOST when it is set and with github.com when it
        is not, and another host throws; someone logged in only to an
        Enterprise host sets GH_HOST.
    .PARAMETER Author
        Only commits by this GitHub user.
    .PARAMETER AuthorName
        Only commits whose author name matches this.
    .PARAMETER AuthorEmail
        Only commits whose author email matches this.
    .PARAMETER AuthorDate
        When the commit was authored: a [datetime], or a date or range as
        text in YYYY-MM-DD form, such as '>2026-01-01' or
        '2026-01-01..2026-01-31'. A [datetime] or [datetimeoffset] must
        be a date with no time of day (give its .Date) and is sent as
        the day it shows; one with a time throws, as GitHub would match
        it to the exact second. For a moment, give text such as
        '>=2026-10-11T09:33:17Z'.
    .PARAMETER Committer
        Only commits committed by this GitHub user.
    .PARAMETER CommitterName
        Only commits whose committer name matches this.
    .PARAMETER CommitterEmail
        Only commits whose committer email matches this.
    .PARAMETER CommitterDate
        When the commit was committed, in the same forms as -AuthorDate.
    .PARAMETER Hash
        Only the commit with this hash.
    .PARAMETER Parent
        Only commits with this parent hash.
    .PARAMETER Tree
        Only commits with this tree hash.
    .PARAMETER Merge
        Only merge commits, or with -Merge:$false only the others.
    .PARAMETER Visibility
        Only commits in repositories with one of these visibilities:
        public, private, or internal.
    .PARAMETER Sort
        Orders by author-date or committer-date. gh's default is
        best-match.
    .PARAMETER Order
        Ascending (asc) or descending (desc, gh's default). Only applies
        with -Sort.
    .PARAMETER Limit
        The most results to fetch, from 1 to 1000. gh's default is 30.
        GitHub returns at most 1000 results for any search.
    .INPUTS
        None
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per commit - Sha, Id, Commit, Author, Committer, Parents,
        Repository, Url.
    .EXAMPLE
        Find-GitHubCommit -Query 'fix typo', '-author:dependabot' `
            -Repository 'cli/cli'

        Finds commits in cli/cli whose message holds the exact phrase "fix
        typo", except those by dependabot.
    .EXAMPLE
        Find-GitHubCommit -Repository 'cli/cli' -Merge:$false `
            -AuthorDate '>2026-01-01'

        Finds the commits in cli/cli authored after the start of 2026 that
        are not merge commits.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Search/README.md
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0)]
        [string[]]$Query,

        [string[]]$Owner,

        [object[]]$Repository,

        [string]$Author,

        [string]$AuthorName,

        [string]$AuthorEmail,

        [object]$AuthorDate,

        [string]$Committer,

        [string]$CommitterName,

        [string]$CommitterEmail,

        [object]$CommitterDate,

        [string]$Hash,

        [string]$Parent,

        [string]$Tree,

        [switch]$Merge,

        [ValidateSet('public', 'private', 'internal')]
        [string[]]$Visibility,

        [ValidateSet('author-date', 'committer-date')]
        [string]$Sort,

        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [ValidateRange(1, 1000)]
        [int]$Limit
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $flags = [ordered]@{
            Owner          = '--owner'
            Repository     = '--repo'
            Author         = '--author'
            AuthorName     = '--author-name'
            AuthorEmail    = '--author-email'
            AuthorDate     = '--author-date'
            Committer      = '--committer'
            CommitterName  = '--committer-name'
            CommitterEmail = '--committer-email'
            CommitterDate  = '--committer-date'
            Hash           = '--hash'
            Parent         = '--parent'
            Tree           = '--tree'
            Merge          = '--merge'
            Visibility     = '--visibility'
            Sort           = '--sort'
            Order          = '--order'
            Limit          = '--limit'
        }

        $search = @{
            Subcommand = 'commits'
            JsonFields = 'author,commit,committer,id,parents,repository,sha,url'
            Command    = $MyInvocation.MyCommand
            Bound      = $PSBoundParameters
            Flag       = $flags
            Date       = @('AuthorDate', 'CommitterDate')
            Query      = $Query
        }
        $arguments = ConvertTo-GitHubSearchArgument @search

        $out = Invoke-GitHubCommand -Activity 'Searching commits' -Argument $arguments
        return ConvertFrom-GitHubJson -Line $out
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
