function Get-GitHubPullRequest {
    <#
    .SYNOPSIS
        Returns one pull request, or lists a repository's pull requests.
    .DESCRIPTION
        Without -List, one pull request is described: the one named, or
        the current branch's. With -List, the repository's open pull
        requests are returned, narrowed by the filters.
    .PARAMETER PullRequest
        The pull request to describe: its number, URL, or head branch.
        Omit it to use the current branch's pull request.
    .PARAMETER List
        Lists pull requests instead of describing one.
    .PARAMETER State
        Lists pull requests in this state: open, closed, merged, or all.
        gh's default is open.
    .PARAMETER Base
        Lists only pull requests into this base branch.
    .PARAMETER Head
        Lists only pull requests from this head branch.
    .PARAMETER Author
        Lists only pull requests by this author. '@me' is the
        authenticated user.
    .PARAMETER App
        Lists only pull requests opened by this GitHub App, such as
        dependabot.
    .PARAMETER Assignee
        Lists only pull requests assigned to this user.
    .PARAMETER Label
        Lists only pull requests carrying every one of these labels.
    .PARAMETER Search
        Lists only pull requests matching this GitHub search query.
    .PARAMETER Draft
        Lists only drafts, or with -Draft:$false only non-drafts.
    .PARAMETER Limit
        The most pull requests to list. gh's default is 30.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object per pull request with Number, Title, State, IsDraft,
        Url, Author, BaseRefName, HeadRefName, HeadRefOid, Labels,
        Assignees, ReviewDecision, Mergeable, MergeStateStatus,
        StatusCheckRollup, Body, and the timestamps. A single object
        without -List; always an array with it.
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'View')]
        [string]$PullRequest,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('open', 'closed', 'merged', 'all')]
        [string]$State,

        [Parameter(ParameterSetName = 'List')]
        [string]$Base,

        [Parameter(ParameterSetName = 'List')]
        [string]$Head,

        [Parameter(ParameterSetName = 'List')]
        [string]$Author,

        [Parameter(ParameterSetName = 'List')]
        [string]$App,

        [Parameter(ParameterSetName = 'List')]
        [string]$Assignee,

        [Parameter(ParameterSetName = 'List')]
        [string[]]$Label,

        [Parameter(ParameterSetName = 'List')]
        [string]$Search,

        [Parameter(ParameterSetName = 'List')]
        [switch]$Draft,

        [Parameter(ParameterSetName = 'List')]
        [int]$Limit,

        [string]$Repository
    )

    $fields = 'additions,assignees,author,autoMergeRequest,baseRefName,body,changedFiles,closedAt,createdAt,deletions,headRefName,headRefOid,headRepository,headRepositoryOwner,isCrossRepository,isDraft,labels,mergeStateStatus,mergeable,mergedAt,mergedBy,milestone,number,reviewDecision,reviewRequests,state,statusCheckRollup,title,updatedAt,url'

    if (-not $List) {
        $arguments = @('pr', 'view')
        if ($PullRequest) {
            $arguments += $PullRequest
        }

        $arguments += @('--json', $fields)
        $out = Invoke-GitHubCommand -Activity 'Reading the pull request' -Arguments $arguments -Repository $Repository
        return ConvertFrom-GitHubJson -Lines $out
    }

    $arguments = @('pr', 'list', '--json', $fields)
    if ($State) {
        $arguments += @('--state', $State)
    }

    if ($Base) {
        $arguments += @('--base', $Base)
    }

    if ($Head) {
        $arguments += @('--head', $Head)
    }

    if ($Author) {
        $arguments += @('--author', $Author)
    }

    if ($App) {
        $arguments += @('--app', $App)
    }

    if ($Assignee) {
        $arguments += @('--assignee', $Assignee)
    }

    foreach ($name in $Label) {
        $arguments += @('--label', $name)
    }

    if ($Search) {
        $arguments += @('--search', $Search)
    }

    if ($PSBoundParameters.ContainsKey('Draft')) {
        $arguments += "--draft=$($Draft.ToString().ToLowerInvariant())"
    }

    if ($Limit -gt 0) {
        $arguments += @('--limit', $Limit)
    }

    $out = Invoke-GitHubCommand -Activity 'Listing pull requests' -Arguments $arguments -Repository $Repository
    $pullRequests = ConvertFrom-GitHubJson -Lines $out
    return , @($pullRequests)
}
