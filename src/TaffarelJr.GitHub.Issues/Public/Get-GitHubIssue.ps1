function Get-GitHubIssue {
    <#
    .SYNOPSIS
        Returns one issue, or lists a repository's issues.
    .DESCRIPTION
        Without -List, one issue is described: the one named. With
        -List, the repository's open issues are returned, narrowed by
        the filters.
    .PARAMETER Issue
        The issue to describe: its number or URL.
    .PARAMETER List
        Lists issues instead of describing one.
    .PARAMETER State
        Lists issues in this state: open, closed, or all. gh's default
        is open.
    .PARAMETER Author
        Lists only issues by this author. '@me' is the authenticated
        user.
    .PARAMETER App
        Lists only issues opened by this GitHub App.
    .PARAMETER Assignee
        Lists only issues assigned to this user.
    .PARAMETER Mention
        Lists only issues mentioning this user.
    .PARAMETER Label
        Lists only issues carrying every one of these labels.
    .PARAMETER Milestone
        Lists only issues in this milestone, by number or title.
    .PARAMETER Type
        Lists only issues of this issue type.
    .PARAMETER Search
        Lists only issues matching this GitHub search query.
    .PARAMETER Limit
        The most issues to list. gh's default is 30.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object per issue with Number, Title, State, StateReason,
        IsPinned, IssueType, Author, Assignees, Labels, Milestone, Body,
        Parent, SubIssues, BlockedBy, Blocking, and the timestamps. A
        single object without -List; always an array with it.
    #>
    [CmdletBinding(DefaultParameterSetName = 'View')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'View', ValueFromPipelineByPropertyName)]
        [Alias('Number')]
        [string]$Issue,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$List,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('open', 'closed', 'all')]
        [string]$State,

        [Parameter(ParameterSetName = 'List')]
        [string]$Author,

        [Parameter(ParameterSetName = 'List')]
        [string]$App,

        [Parameter(ParameterSetName = 'List')]
        [string]$Assignee,

        [Parameter(ParameterSetName = 'List')]
        [string]$Mention,

        [Parameter(ParameterSetName = 'List')]
        [string[]]$Label,

        [Parameter(ParameterSetName = 'List')]
        [string]$Milestone,

        [Parameter(ParameterSetName = 'List')]
        [string]$Type,

        [Parameter(ParameterSetName = 'List')]
        [string]$Search,

        [Parameter(ParameterSetName = 'List')]
        [int]$Limit,

        [string]$Repository
    )

    process {
        $fields = 'assignees,author,blockedBy,blocking,body,closed,closedAt,closedByPullRequestsReferences,comments,createdAt,id,isPinned,issueType,labels,milestone,number,parent,projectCards,projectItems,reactionGroups,state,stateReason,subIssues,subIssuesSummary,title,updatedAt,url'

        if (-not $List) {
            $arguments = @('issue', 'view')
            if ($Issue) {
                $arguments += $Issue
            }

            $arguments += @('--json', $fields)
            $out = Invoke-GitHubCommand -Activity 'Reading the issue' -Arguments $arguments -Repository $Repository
            return ConvertFrom-GitHubJson -Lines $out
        }

        $arguments = @('issue', 'list', '--json', $fields)
        if ($State) {
            $arguments += @('--state', $State)
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

        if ($Mention) {
            $arguments += @('--mention', $Mention)
        }

        foreach ($name in $Label) {
            $arguments += @('--label', $name)
        }

        if ($Milestone) {
            $arguments += @('--milestone', $Milestone)
        }

        if ($Type) {
            $arguments += @('--type', $Type)
        }

        if ($Search) {
            $arguments += @('--search', $Search)
        }

        if ($Limit -gt 0) {
            $arguments += @('--limit', $Limit)
        }

        $out = Invoke-GitHubCommand -Activity 'Listing issues' -Arguments $arguments -Repository $Repository
        $issues = ConvertFrom-GitHubJson -Lines $out
        return , @($issues)
    }
}
