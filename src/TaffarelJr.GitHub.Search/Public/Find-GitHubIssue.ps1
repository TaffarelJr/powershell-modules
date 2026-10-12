function Find-GitHubIssue {
    <#
    .SYNOPSIS
        Searches GitHub for issues.
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
        phrase, so 'broken feature' is one phrase where 'broken', 'feature'
        is two keywords. A qualifier such as label:bug is a value of its
        own, and one starting with a dash excludes (-label:bug).
    .PARAMETER Owner
        Only issues in repositories owned by one of these users or
        organizations.
    .PARAMETER Repository
        Only issues in one of these repositories, each as OWNER/REPO,
        a URL, HOST/OWNER/REPO, or a repository object such as another
        search result's Repository; gh is given its OWNER/REPO. gh
        searches its default host - the one GH_HOST names, else the one
        host gh is logged in to, else github.com. A named host is
        compared with GH_HOST when it is set and with github.com when it
        is not, and another host throws; someone logged in only to an
        Enterprise host sets GH_HOST.
    .PARAMETER App
        Only issues opened by this GitHub App. Not with -Author.
    .PARAMETER Author
        Only issues by this author. Not with -App.
    .PARAMETER Assignee
        Only issues assigned to this user.
    .PARAMETER Mention
        Only issues mentioning this user. It takes one user; -Mentions
        works too.
    .PARAMETER TeamMention
        Only issues mentioning this team. It takes one team;
        -TeamMentions works too.
    .PARAMETER Commenter
        Only issues commented on by this user.
    .PARAMETER Involves
        Only issues this user is involved in, any way.
    .PARAMETER State
        Only issues in this state: open or closed.
    .PARAMETER Label
        Only issues carrying every one of these labels.
    .PARAMETER NoLabel
        Only issues with no label. It has no false form: gh ignores it,
        so -NoLabel:$false throws.
    .PARAMETER Milestone
        Only issues in this milestone, by title.
    .PARAMETER NoMilestone
        Only issues with no milestone. It has no false form, so
        -NoMilestone:$false throws.
    .PARAMETER NoAssignee
        Only issues with no assignee. It has no false form, so
        -NoAssignee:$false throws.
    .PARAMETER NoProject
        Only issues on no project. It has no false form, so
        -NoProject:$false throws.
    .PARAMETER Project
        Only issues on this project board, as OWNER/NUMBER.
    .PARAMETER Language
        Only issues in repositories whose primary language is this.
    .PARAMETER Visibility
        Only issues in repositories with one of these visibilities:
        public, private, or internal.
    .PARAMETER Archived
        Only issues in archived repositories, or with -Archived:$false
        only the others.
    .PARAMETER Locked
        Only issues with a locked conversation, or with -Locked:$false only
        the others.
    .PARAMETER IncludePullRequests
        Includes pull requests among the results. It has no false form,
        as leaving it off already means issues only, so
        -IncludePullRequests:$false throws.
    .PARAMETER Comments
        A comment-count range, such as '>10'.
    .PARAMETER Interactions
        A range on the combined reaction and comment count.
    .PARAMETER Reactions
        A reaction-count range.
    .PARAMETER Created
        When the issue was created: a [datetime], or a date or range as
        text in YYYY-MM-DD form, such as '>2026-01-01' or
        '2026-01-01..2026-01-31'. A [datetime] or [datetimeoffset] must
        be a date with no time of day (give its .Date) and is sent as
        the day it shows; one with a time throws, as GitHub would match
        it to the exact second. For a moment, give text such as
        '>=2026-10-11T09:33:17Z'.
    .PARAMETER Updated
        When the issue was last updated, in the same forms as -Created.
    .PARAMETER Closed
        When the issue was closed, in the same forms as -Created.
    .PARAMETER Match
        Restricts the search to specific fields: title, body, or
        comments.
    .PARAMETER SearchType
        The kind of search to perform: lexical, semantic, or hybrid. gh's
        default is lexical. Needs gh 2.98 or later. Semantic and hybrid
        searches cannot be combined with -Sort, -Order, or
        -IncludePullRequests.
    .PARAMETER Sort
        Orders the results by comments, created, interactions, reactions,
        reactions-+1, reactions--1, reactions-heart, reactions-smile,
        reactions-tada, reactions-thinking_face, or updated. gh's default
        is best-match.
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
        One object per issue - Number, Title, Body, State, Author,
        AuthorAssociation, Assignees, Labels, Repository, Url, Id, IsLocked,
        IsPullRequest, CommentsCount, CreatedAt, UpdatedAt, and ClosedAt,
        which is $null for an open issue.
    .EXAMPLE
        Find-GitHubIssue -Query 'crash on start', '-label:wontfix' `
            -Repository 'cli/cli'

        Finds issues in cli/cli holding the exact phrase "crash on start",
        except those labeled wontfix.
    .EXAMPLE
        Find-GitHubIssue -Owner 'cli' -State open -Locked:$false -Limit 10

        Finds ten open issues in cli's repositories whose conversation is
        not locked.
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

        [string]$App,

        [string]$Author,

        [string]$Assignee,

        [Alias('Mentions')]
        [string]$Mention,

        [Alias('TeamMentions')]
        [string]$TeamMention,

        [string]$Commenter,

        [string]$Involves,

        [ValidateSet('open', 'closed')]
        [string]$State,

        [string[]]$Label,

        [switch]$NoLabel,

        [string]$Milestone,

        [switch]$NoMilestone,

        [switch]$NoAssignee,

        [switch]$NoProject,

        [string]$Project,

        [string]$Language,

        [ValidateSet('public', 'private', 'internal')]
        [string[]]$Visibility,

        [switch]$Archived,

        [switch]$Locked,

        [switch]$IncludePullRequests,

        [string]$Comments,

        [string]$Interactions,

        [string]$Reactions,

        [object]$Created,

        [object]$Updated,

        [object]$Closed,

        [ValidateSet('title', 'body', 'comments')]
        [string[]]$Match,

        [ValidateSet('lexical', 'semantic', 'hybrid')]
        [string]$SearchType,

        [ValidateSet(
            'comments', 'created', 'interactions', 'reactions', 'reactions-+1', 'reactions--1',
            'reactions-heart', 'reactions-smile', 'reactions-tada', 'reactions-thinking_face', 'updated'
        )]
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

        if ($PSBoundParameters.ContainsKey('Author') -and $PSBoundParameters.ContainsKey('App')) {
            throw '-Author and -App cannot be used together: gh searches by one author or the other. Give only one.'
        }

        if ($SearchType -in 'semantic', 'hybrid') {
            $bound = $PSBoundParameters
            $unsupported = @('Sort', 'Order', 'IncludePullRequests' | Where-Object { $bound.ContainsKey($_) })
            if ($unsupported.Count -gt 0) {
                throw "-SearchType $($SearchType.ToLowerInvariant()) and -$($unsupported -join ', -') cannot be " +
                    'used together: gh supports those with a lexical search only. Give only one.'
            }
        }

        $flags = [ordered]@{
            Owner               = '--owner'
            Repository          = '--repo'
            App                 = '--app'
            Author              = '--author'
            Assignee            = '--assignee'
            Mention             = '--mentions'
            TeamMention         = '--team-mentions'
            Commenter           = '--commenter'
            Involves            = '--involves'
            State               = '--state'
            Label               = '--label'
            NoLabel             = '--no-label'
            Milestone           = '--milestone'
            NoMilestone         = '--no-milestone'
            NoAssignee          = '--no-assignee'
            NoProject           = '--no-project'
            Project             = '--project'
            Language            = '--language'
            Visibility          = '--visibility'
            Archived            = '--archived'
            Locked              = '--locked'
            IncludePullRequests = '--include-prs'
            Comments            = '--comments'
            Interactions        = '--interactions'
            Reactions           = '--reactions'
            Created             = '--created'
            Updated             = '--updated'
            Closed              = '--closed'
            Match               = '--match'
            SearchType          = '--search-type'
            Sort                = '--sort'
            Order               = '--order'
            Limit               = '--limit'
        }

        $fields = @(
            'assignees', 'author', 'authorAssociation', 'body', 'closedAt', 'commentsCount', 'createdAt', 'id',
            'isLocked', 'isPullRequest', 'labels', 'number', 'repository', 'state', 'title', 'updatedAt', 'url'
        )
        $search = @{
            Subcommand  = 'issues'
            JsonFields  = $fields -join ','
            Command     = $MyInvocation.MyCommand
            Bound       = $PSBoundParameters
            Flag        = $flags
            Date        = @('Created', 'Updated', 'Closed')
            PresentOnly = @('NoLabel', 'NoMilestone', 'NoAssignee', 'NoProject', 'IncludePullRequests')
            Query       = $Query
        }
        $arguments = ConvertTo-GitHubSearchArgument @search

        $out = Invoke-GitHubCommand -Activity 'Searching issues' -Argument $arguments
        return ConvertFrom-GitHubJson -Line $out
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
