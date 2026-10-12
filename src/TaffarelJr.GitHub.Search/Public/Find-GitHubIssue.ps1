function Find-GitHubIssue {
    <#
    .SYNOPSIS
        Searches GitHub for issues.
    .PARAMETER Query
        Search keywords. Omit it to rely on the filters alone.
    .PARAMETER Owner
        Only issues in repositories owned by one of these users or
        organizations.
    .PARAMETER Repository
        Only issues in this repository, in OWNER/REPO form.
    .PARAMETER App
        Only issues opened by this GitHub App.
    .PARAMETER Author
        Only issues by this author.
    .PARAMETER Assignee
        Only issues assigned to this user.
    .PARAMETER Mentions
        Only issues mentioning this user.
    .PARAMETER TeamMentions
        Only issues mentioning this team.
    .PARAMETER Commenter
        Only issues commented on by this user.
    .PARAMETER Involves
        Only issues this user is involved in, any way.
    .PARAMETER State
        Only issues in this state: open or closed.
    .PARAMETER Label
        Only issues carrying every one of these labels.
    .PARAMETER NoLabel
        Only issues with no label.
    .PARAMETER Milestone
        Only issues in this milestone, by title.
    .PARAMETER NoMilestone
        Only issues with no milestone.
    .PARAMETER NoAssignee
        Only issues with no assignee.
    .PARAMETER NoProject
        Only issues on no project.
    .PARAMETER Project
        Only issues on this project board, as OWNER/NUMBER.
    .PARAMETER Language
        Only issues in repositories whose primary language is this.
    .PARAMETER Visibility
        Only issues in repositories with one of these visibilities:
        public, private, or internal.
    .PARAMETER Archived
        Only issues in repositories that are archived ($true) or not
        ($false).
    .PARAMETER Locked
        Only issues with a locked conversation.
    .PARAMETER IncludePullRequests
        Includes pull requests among the results.
    .PARAMETER Comments
        A comment-count range, such as '>10'.
    .PARAMETER Interactions
        A range on the combined reaction and comment count.
    .PARAMETER Reactions
        A reaction-count range.
    .PARAMETER Created
        A date range on when the issue was created.
    .PARAMETER Updated
        A date range on when the issue was last updated.
    .PARAMETER Closed
        A date range on when the issue was closed.
    .PARAMETER Match
        Restricts the search to specific fields: title, body, or
        comments.
    .PARAMETER SearchType
        The kind of search to perform: lexical, semantic, or hybrid. gh's
        default is lexical.
    .PARAMETER Sort
        Orders the results by a field such as created, updated, or
        reactions. gh's default is best-match.
    .PARAMETER Order
        Ascending (asc) or descending (desc, gh's default). Only applies
        with -Sort.
    .PARAMETER Limit
        The most results to fetch. gh's default is 30.
    .OUTPUTS
        One object per issue - Number, Title, State, Author, Labels,
        Assignees, Repository, Url, IsLocked, CommentsCount, and the
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

        [switch]$IncludePullRequests,

        [string]$Comments,

        [string]$Interactions,

        [string]$Reactions,

        [string]$Created,

        [string]$Updated,

        [string]$Closed,

        [ValidateSet('title', 'body', 'comments')]
        [string[]]$Match,

        [ValidateSet('lexical', 'semantic', 'hybrid')]
        [string]$SearchType,

        [string]$Sort,

        [ValidateSet('asc', 'desc')]
        [string]$Order,

        [int]$Limit
    )

    $fields = 'assignees,author,authorAssociation,body,closedAt,commentsCount,createdAt,id,isLocked,isPullRequest,labels,number,repository,state,title,updatedAt,url'
    $arguments = @('search', 'issues')
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

    if ($IncludePullRequests) {
        $arguments += '--include-prs'
    }

    if ($Comments) {
        $arguments += @('--comments', $Comments)
    }

    if ($Interactions) {
        $arguments += @('--interactions', $Interactions)
    }

    if ($Reactions) {
        $arguments += @('--reactions', $Reactions)
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

    if ($SearchType) {
        $arguments += @('--search-type', $SearchType)
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

    $out = Invoke-GitHubCommand -Activity 'Searching issues' -Arguments $arguments -Repository $Repository
    $issues = ConvertFrom-GitHubJson -Lines $out
    return , @($issues)
}
