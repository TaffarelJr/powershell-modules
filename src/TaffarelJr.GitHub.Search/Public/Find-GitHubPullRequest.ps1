function Find-GitHubPullRequest {
    <#
    .SYNOPSIS
        Searches GitHub for pull requests.
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
        keywords. A qualifier such as label:bug is a value of its own, and
        one starting with a dash excludes (-label:bug).
    .PARAMETER Owner
        Only pull requests in repositories owned by one of these users or
        organizations.
    .PARAMETER Repository
        Only pull requests in one of these repositories, each as OWNER/REPO,
        a URL, HOST/OWNER/REPO, or a repository object such as another
        search result's Repository; gh is given its OWNER/REPO. gh
        searches its default host - the one GH_HOST names, else the one
        host gh is logged in to, else github.com. A named host is
        compared with GH_HOST when it is set and with github.com when it
        is not, and another host throws; someone logged in only to an
        Enterprise host sets GH_HOST.
    .PARAMETER App
        Only pull requests opened by this GitHub App. Not with -Author.
    .PARAMETER Author
        Only pull requests by this author. Not with -App.
    .PARAMETER Assignee
        Only pull requests assigned to this user.
    .PARAMETER Mention
        Only pull requests mentioning this user. It takes one user;
        -Mentions works too.
    .PARAMETER TeamMention
        Only pull requests mentioning this team. It takes one team;
        -TeamMentions works too.
    .PARAMETER Commenter
        Only pull requests commented on by this user.
    .PARAMETER Involves
        Only pull requests this user is involved in, any way.
    .PARAMETER State
        Only pull requests in this state: open or closed.
    .PARAMETER Base
        Only pull requests targeting this base branch.
    .PARAMETER Head
        Only pull requests from this head branch.
    .PARAMETER Draft
        Only draft pull requests, or with -Draft:$false only the others.
    .PARAMETER Merged
        Only merged pull requests, or with -Merged:$false only the others.
    .PARAMETER MergedAt
        When the pull request was merged: a [datetime], or a date or range
        as text in YYYY-MM-DD form, such as '>2026-01-01' or
        '2026-01-01..2026-01-31'. A [datetime] or [datetimeoffset] must
        be a date with no time of day (give its .Date) and is sent as
        the day it shows; one with a time throws, as GitHub would match
        it to the exact second. For a moment, give text such as
        '>=2026-10-11T09:33:17Z'.
    .PARAMETER Checks
        Only pull requests whose checks are in this state: pending,
        success, or failure.
    .PARAMETER Review
        Only pull requests with this review status: none, required,
        approved, or changes_requested.
    .PARAMETER ReviewRequested
        Only pull requests whose review was requested from this user or
        team.
    .PARAMETER ReviewedBy
        Only pull requests reviewed by this user.
    .PARAMETER Label
        Only pull requests carrying every one of these labels.
    .PARAMETER NoLabel
        Only pull requests with no label. It has no false form: gh
        ignores it, so -NoLabel:$false throws.
    .PARAMETER Milestone
        Only pull requests in this milestone, by title.
    .PARAMETER NoMilestone
        Only pull requests with no milestone. It has no false form, so
        -NoMilestone:$false throws.
    .PARAMETER NoAssignee
        Only pull requests with no assignee. It has no false form, so
        -NoAssignee:$false throws.
    .PARAMETER NoProject
        Only pull requests on no project. It has no false form, so
        -NoProject:$false throws.
    .PARAMETER Project
        Only pull requests on this project board, as OWNER/NUMBER.
    .PARAMETER Language
        Only pull requests in repositories whose primary language is
        this.
    .PARAMETER Visibility
        Only pull requests in repositories with one of these
        visibilities: public, private, or internal.
    .PARAMETER Archived
        Only pull requests in archived repositories, or with
        -Archived:$false only the others.
    .PARAMETER Locked
        Only pull requests with a locked conversation, or with
        -Locked:$false only the others. gh ignores its own
        --locked=false for pull requests, so the false form is sent as
        the keyword is:unlocked.
    .PARAMETER Comments
        A comment-count range, such as '>10'.
    .PARAMETER Interactions
        A range on the combined reaction and comment count.
    .PARAMETER Reactions
        A reaction-count range.
    .PARAMETER Created
        When the pull request was created, in the same forms as
        -MergedAt.
    .PARAMETER Updated
        When the pull request was last updated, in the same forms as
        -MergedAt.
    .PARAMETER Closed
        When the pull request was closed, in the same forms as -MergedAt.
    .PARAMETER Match
        Restricts the search to specific fields: title, body, or
        comments.
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
        One object per pull request - Number, Title, Body, State, IsDraft,
        Author, AuthorAssociation, Assignees, Labels, Repository, Url, Id,
        IsLocked, IsPullRequest, CommentsCount, CreatedAt, UpdatedAt, and
        ClosedAt, which is $null for an open pull request.
    .EXAMPLE
        Find-GitHubPullRequest -Query 'fix typo', '-label:wip' `
            -Repository 'cli/cli' -State open

        Finds open pull requests in cli/cli holding the exact phrase "fix
        typo", except those labeled wip.
    .EXAMPLE
        Find-GitHubPullRequest -Repository 'cli/cli' -Draft:$false `
            -Merged:$false -State open

        Finds the open pull requests in cli/cli that are ready for review.
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

        [string]$Base,

        [string]$Head,

        [switch]$Draft,

        [switch]$Merged,

        [object]$MergedAt,

        [ValidateSet('pending', 'success', 'failure')]
        [string]$Checks,

        [ValidateSet('none', 'required', 'approved', 'changes_requested')]
        [string]$Review,

        [string]$ReviewRequested,

        [string]$ReviewedBy,

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

        [string]$Comments,

        [string]$Interactions,

        [string]$Reactions,

        [object]$Created,

        [object]$Updated,

        [object]$Closed,

        [ValidateSet('title', 'body', 'comments')]
        [string[]]$Match,

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

        $flags = [ordered]@{
            Owner           = '--owner'
            Repository      = '--repo'
            App             = '--app'
            Author          = '--author'
            Assignee        = '--assignee'
            Mention         = '--mentions'
            TeamMention     = '--team-mentions'
            Commenter       = '--commenter'
            Involves        = '--involves'
            State           = '--state'
            Base            = '--base'
            Head            = '--head'
            Draft           = '--draft'
            Merged          = '--merged'
            MergedAt        = '--merged-at'
            Checks          = '--checks'
            Review          = '--review'
            ReviewRequested = '--review-requested'
            ReviewedBy      = '--reviewed-by'
            Label           = '--label'
            NoLabel         = '--no-label'
            Milestone       = '--milestone'
            NoMilestone     = '--no-milestone'
            NoAssignee      = '--no-assignee'
            NoProject       = '--no-project'
            Project         = '--project'
            Language        = '--language'
            Visibility      = '--visibility'
            Archived        = '--archived'
            Locked          = '--locked'
            Comments        = '--comments'
            Interactions    = '--interactions'
            Reactions       = '--reactions'
            Created         = '--created'
            Updated         = '--updated'
            Closed          = '--closed'
            Match           = '--match'
            Sort            = '--sort'
            Order           = '--order'
            Limit           = '--limit'
        }

        $fields = @(
            'assignees', 'author', 'authorAssociation', 'body', 'closedAt', 'commentsCount', 'createdAt', 'id',
            'isDraft', 'isLocked', 'isPullRequest', 'labels', 'number', 'repository', 'state', 'title', 'updatedAt',
            'url'
        )
        $search = @{
            Subcommand   = 'prs'
            JsonFields   = $fields -join ','
            Command      = $MyInvocation.MyCommand
            Bound        = $PSBoundParameters
            Flag         = $flags
            Date         = @('MergedAt', 'Created', 'Updated', 'Closed')
            PresentOnly  = @('NoLabel', 'NoMilestone', 'NoAssignee', 'NoProject')
            FalseKeyword = @{ Locked = 'is:unlocked' }
            Query        = $Query
        }
        $arguments = ConvertTo-GitHubSearchArgument @search

        $out = Invoke-GitHubCommand -Activity 'Searching pull requests' -Argument $arguments
        return ConvertFrom-GitHubJson -Line $out
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
