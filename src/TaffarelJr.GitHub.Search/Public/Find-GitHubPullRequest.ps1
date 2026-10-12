function Find-GitHubPullRequest {
    <#
    .SYNOPSIS
        Searches GitHub for pull requests.
    .PARAMETER Query
        Search keywords. Omit it to rely on the filters alone.
    .PARAMETER Owner
        Only pull requests in repositories owned by one of these users or
        organizations.
    .PARAMETER Repository
        Only pull requests in this repository, in OWNER/REPO form.
    .PARAMETER App
        Only pull requests opened by this GitHub App.
    .PARAMETER Author
        Only pull requests by this author.
    .PARAMETER Assignee
        Only pull requests assigned to this user.
    .PARAMETER Mentions
        Only pull requests mentioning this user.
    .PARAMETER TeamMentions
        Only pull requests mentioning this team.
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
        Only draft pull requests.
    .PARAMETER Merged
        Only merged pull requests.
    .PARAMETER MergedAt
        A date range on when the pull request was merged.
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
        Only pull requests with no label.
    .PARAMETER Milestone
        Only pull requests in this milestone, by title.
    .PARAMETER NoMilestone
        Only pull requests with no milestone.
    .PARAMETER NoAssignee
        Only pull requests with no assignee.
    .PARAMETER NoProject
        Only pull requests on no project.
    .PARAMETER Project
        Only pull requests on this project board, as OWNER/NUMBER.
    .PARAMETER Language
        Only pull requests in repositories whose primary language is
        this.
    .PARAMETER Visibility
        Only pull requests in repositories with one of these
        visibilities: public, private, or internal.
    .PARAMETER Archived
        Only pull requests in repositories that are archived ($true) or
        not ($false).
    .PARAMETER Locked
        Only pull requests with a locked conversation.
    .PARAMETER Comments
        A comment-count range, such as '>10'.
    .PARAMETER Interactions
        A range on the combined reaction and comment count.
    .PARAMETER Created
        A date range on when the pull request was created.
    .PARAMETER Updated
        A date range on when the pull request was last updated.
    .PARAMETER Closed
        A date range on when the pull request was closed.
    .PARAMETER Match
        Restricts the search to specific fields: title, body, or
        comments.
    .PARAMETER Sort
        Orders the results by a field such as created, updated, or
        interactions. gh's default is best-match.
    .PARAMETER Order
        Ascending (asc) or descending (desc, gh's default). Only applies
        with -Sort.
    .PARAMETER Limit
        The most results to fetch. gh's default is 30.
    .OUTPUTS
        One object per pull request - Number, Title, State, IsDraft,
        Author, Labels, Repository, Url, IsLocked, CommentsCount, and the
        timestamps - always an array.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Query,

        [string[]]$Owner,

        [string]$Repository,

        [string]$App,

        [string]$Author,

        [string]$Assignee,

        [string]$Mentions,

        [string]$TeamMentions,

        [string]$Commenter,

        [string]$Involves,

        [ValidateSet('open', 'closed')]
        [string]$State,

        [string]$Base,

        [string]$Head,

        [switch]$Draft,

        [switch]$Merged,

        [string]$MergedAt,

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

        [string[]]$Visibility,

        [bool]$Archived,

        [switch]$Locked,

        [string]$Comments,

        [string]$Interactions,

        [string]$Created,

        [string]$Updated,

        [string]$Closed,

        [ValidateSet('title', 'body', 'comments')]
        [string[]]$Match,

        [string]$Sort,

        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [int]$Limit
    )

    $fields = 'assignees,author,authorAssociation,body,closedAt,commentsCount,createdAt,id,isDraft,isLocked,isPullRequest,labels,number,repository,state,title,updatedAt,url'
    $arguments = @('search', 'prs')
    if ($Query) {
        $arguments += $Query
    }

    $arguments += @('--json', $fields)
    foreach ($name in $Owner) {
        $arguments += @('--owner', $name)
    }

    if ($App) {
        $arguments += @('--app', $App)
    }

    if ($Author) {
        $arguments += @('--author', $Author)
    }

    if ($Assignee) {
        $arguments += @('--assignee', $Assignee)
    }

    if ($Mentions) {
        $arguments += @('--mentions', $Mentions)
    }

    if ($TeamMentions) {
        $arguments += @('--team-mentions', $TeamMentions)
    }

    if ($Commenter) {
        $arguments += @('--commenter', $Commenter)
    }

    if ($Involves) {
        $arguments += @('--involves', $Involves)
    }

    if ($State) {
        $arguments += @('--state', $State)
    }

    if ($Base) {
        $arguments += @('--base', $Base)
    }

    if ($Head) {
        $arguments += @('--head', $Head)
    }

    if ($Draft) {
        $arguments += '--draft'
    }

    if ($Merged) {
        $arguments += '--merged'
    }

    if ($MergedAt) {
        $arguments += @('--merged-at', $MergedAt)
    }

    if ($Checks) {
        $arguments += @('--checks', $Checks)
    }

    if ($Review) {
        $arguments += @('--review', $Review)
    }

    if ($ReviewRequested) {
        $arguments += @('--review-requested', $ReviewRequested)
    }

    if ($ReviewedBy) {
        $arguments += @('--reviewed-by', $ReviewedBy)
    }

    foreach ($name in $Label) {
        $arguments += @('--label', $name)
    }

    if ($NoLabel) {
        $arguments += '--no-label'
    }

    if ($Milestone) {
        $arguments += @('--milestone', $Milestone)
    }

    if ($NoMilestone) {
        $arguments += '--no-milestone'
    }

    if ($NoAssignee) {
        $arguments += '--no-assignee'
    }

    if ($NoProject) {
        $arguments += '--no-project'
    }

    if ($Project) {
        $arguments += @('--project', $Project)
    }

    if ($Language) {
        $arguments += @('--language', $Language)
    }

    foreach ($value in $Visibility) {
        $arguments += @('--visibility', $value)
    }

    if ($PSBoundParameters.ContainsKey('Archived')) {
        $arguments += @('--archived', $Archived.ToString().ToLowerInvariant())
    }

    if ($Locked) {
        $arguments += '--locked'
    }

    if ($Comments) {
        $arguments += @('--comments', $Comments)
    }

    if ($Interactions) {
        $arguments += @('--interactions', $Interactions)
    }

    if ($Created) {
        $arguments += @('--created', $Created)
    }

    if ($Updated) {
        $arguments += @('--updated', $Updated)
    }

    if ($Closed) {
        $arguments += @('--closed', $Closed)
    }

    foreach ($field in $Match) {
        $arguments += @('--match', $field)
    }

    if ($Sort) {
        $arguments += @('--sort', $Sort)
    }

    if ($Order) {
        $arguments += @('--order', $Order)
    }

    if ($Limit -gt 0) {
        $arguments += @('--limit', $Limit)
    }

    $out = Invoke-GitHubCommand -Activity 'Searching pull requests' -Arguments $arguments -Repository $Repository
    $pullRequests = ConvertFrom-GitHubJson -Lines $out
    return , @($pullRequests)
}
