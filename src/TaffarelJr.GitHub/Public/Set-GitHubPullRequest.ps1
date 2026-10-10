function Set-GitHubPullRequest {
    <#
    .SYNOPSIS
        Changes a pull request's title, body, base, labels, people, or
        draft state.
    .DESCRIPTION
        The body travels to gh on standard input, so a long or multi-line
        body arrives intact. -Ready marks a draft ready for review, and
        -Ready:$false turns a pull request back into a draft; either can
        combine with the other edits in one call.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch. Omit it to use
        the current branch's pull request.
    .PARAMETER Title
        The new title.
    .PARAMETER Body
        The new body, as Markdown.
    .PARAMETER Base
        The new base branch.
    .PARAMETER Milestone
        The milestone to move the pull request to, by name.
    .PARAMETER RemoveMilestone
        Takes the pull request out of its milestone.
    .PARAMETER AddLabel
        Labels to add.
    .PARAMETER RemoveLabel
        Labels to remove.
    .PARAMETER AddAssignee
        Users to assign, by login. '@me' is the authenticated user.
    .PARAMETER RemoveAssignee
        Users to unassign, by login.
    .PARAMETER AddReviewer
        Users or teams to request (or re-request) a review from.
    .PARAMETER RemoveReviewer
        Users or teams whose review request to withdraw.
    .PARAMETER AddProject
        Projects to add the pull request to, by title.
    .PARAMETER RemoveProject
        Projects to remove the pull request from, by title.
    .PARAMETER Ready
        Marks the pull request ready for review, or with -Ready:$false
        converts it to a draft.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$PullRequest,

        [string]$Title,

        [string]$Body,

        [string]$Base,

        [string]$Milestone,

        [switch]$RemoveMilestone,

        [string[]]$AddLabel,

        [string[]]$RemoveLabel,

        [string[]]$AddAssignee,

        [string[]]$RemoveAssignee,

        [string[]]$AddReviewer,

        [string[]]$RemoveReviewer,

        [string[]]$AddProject,

        [string[]]$RemoveProject,

        [switch]$Ready,

        [string]$Repository
    )

    $target = @()
    if ($PullRequest) {
        $target += $PullRequest
    }

    $edits = @()
    if ($Title) {
        $edits += @('--title', $Title)
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $edits += @('--body-file', '-')
    }

    if ($Base) {
        $edits += @('--base', $Base)
    }

    if ($Milestone) {
        $edits += @('--milestone', $Milestone)
    }

    if ($RemoveMilestone) {
        $edits += '--remove-milestone'
    }

    $lists = [ordered]@{
        '--add-label'       = $AddLabel
        '--remove-label'    = $RemoveLabel
        '--add-assignee'    = $AddAssignee
        '--remove-assignee' = $RemoveAssignee
        '--add-reviewer'    = $AddReviewer
        '--remove-reviewer' = $RemoveReviewer
        '--add-project'     = $AddProject
        '--remove-project'  = $RemoveProject
    }
    foreach ($flag in $lists.Keys) {
        foreach ($value in $lists[$flag]) {
            $edits += @($flag, $value)
        }
    }

    if ($edits.Count -gt 0) {
        $extra = @{}
        if ($PSBoundParameters.ContainsKey('Body')) {
            $extra['StdIn'] = $Body
        }

        $arguments = @('pr', 'edit') + $target + $edits
        Invoke-GitHubCommand -Activity 'Editing the pull request' -Arguments $arguments -Repository $Repository @extra | Out-Null
    }

    if ($PSBoundParameters.ContainsKey('Ready')) {
        $arguments = @('pr', 'ready') + $target
        if (-not $Ready) {
            $arguments += '--undo'
        }

        Invoke-GitHubCommand -Activity "Changing the pull request's draft state" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
