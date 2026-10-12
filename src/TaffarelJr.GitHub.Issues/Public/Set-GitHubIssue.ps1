function Set-GitHubIssue {
    <#
    .SYNOPSIS
        Changes an issue's title, body, labels, people, type, milestone,
        parent, sub-issues, blocking relationships, or pinned state.
    .DESCRIPTION
        The body travels to gh on standard input, so multi-line Markdown
        arrives intact. -Pinned is a three-state toggle: omitted leaves
        it alone, given pins the issue, and given as $false unpins it.
    .PARAMETER Issue
        The issue to change: its number or URL.
    .PARAMETER Title
        The new title.
    .PARAMETER Body
        The new body, as Markdown.
    .PARAMETER Milestone
        The milestone to move the issue to, by name.
    .PARAMETER RemoveMilestone
        Takes the issue out of its milestone.
    .PARAMETER AddLabel
        Labels to add.
    .PARAMETER RemoveLabel
        Labels to remove.
    .PARAMETER AddAssignee
        Users to assign, by login. '@me' is the authenticated user.
    .PARAMETER RemoveAssignee
        Users to unassign, by login.
    .PARAMETER AddProject
        Projects to add the issue to, by title.
    .PARAMETER RemoveProject
        Projects to remove the issue from, by title.
    .PARAMETER Type
        The new issue type, by name.
    .PARAMETER RemoveType
        Removes the issue's type.
    .PARAMETER Parent
        Sets the parent issue, by number or URL.
    .PARAMETER RemoveParent
        Removes the parent issue relationship.
    .PARAMETER AddSubIssue
        Sub-issues to add, by number or URL.
    .PARAMETER RemoveSubIssue
        Sub-issues to remove, by number or URL.
    .PARAMETER AddBlockedBy
        'Blocked by' relationships to add, by issue number or URL.
    .PARAMETER RemoveBlockedBy
        'Blocked by' relationships to remove, by issue number or URL.
    .PARAMETER AddBlocking
        'Blocking' relationships to add, by issue number or URL.
    .PARAMETER RemoveBlocking
        'Blocking' relationships to remove, by issue number or URL.
    .PARAMETER Pinned
        Pins the issue, or with -Pinned:$false unpins it.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('Number')]
        [string]$Issue,

        [string]$Title,

        [string]$Body,

        [string]$Milestone,

        [switch]$RemoveMilestone,

        [string[]]$AddLabel,

        [string[]]$RemoveLabel,

        [string[]]$AddAssignee,

        [string[]]$RemoveAssignee,

        [string[]]$AddProject,

        [string[]]$RemoveProject,

        [string]$Type,

        [switch]$RemoveType,

        [string]$Parent,

        [switch]$RemoveParent,

        [string[]]$AddSubIssue,

        [string[]]$RemoveSubIssue,

        [string[]]$AddBlockedBy,

        [string[]]$RemoveBlockedBy,

        [string[]]$AddBlocking,

        [string[]]$RemoveBlocking,

        [switch]$Pinned,

        [string]$Repository
    )

    process {
        $edits = @()
        if ($Title) {
            $edits += @('--title', $Title)
        }

        if ($PSBoundParameters.ContainsKey('Body')) {
            $edits += @('--body-file', '-')
        }

        if ($Milestone) {
            $edits += @('--milestone', $Milestone)
        }

        if ($RemoveMilestone) {
            $edits += '--remove-milestone'
        }

        if ($Type) {
            $edits += @('--type', $Type)
        }

        if ($RemoveType) {
            $edits += '--remove-type'
        }

        if ($Parent) {
            $edits += @('--parent', $Parent)
        }

        if ($RemoveParent) {
            $edits += '--remove-parent'
        }

        $lists = [ordered]@{
            '--add-label'        = $AddLabel
            '--remove-label'     = $RemoveLabel
            '--add-assignee'     = $AddAssignee
            '--remove-assignee'  = $RemoveAssignee
            '--add-project'      = $AddProject
            '--remove-project'   = $RemoveProject
            '--add-sub-issue'    = $AddSubIssue
            '--remove-sub-issue' = $RemoveSubIssue
            '--add-blocked-by'   = $AddBlockedBy
            '--remove-blocked-by' = $RemoveBlockedBy
            '--add-blocking'     = $AddBlocking
            '--remove-blocking'  = $RemoveBlocking
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

            $arguments = @('issue', 'edit', $Issue) + $edits
            Invoke-GitHubCommand -Activity 'Editing the issue' -Arguments $arguments -Repository $Repository @extra | Out-Null
        }

        if ($PSBoundParameters.ContainsKey('Pinned')) {
            $subcommand = if ($Pinned) { 'pin' } else { 'unpin' }
            $arguments = @('issue', $subcommand, $Issue)
            Invoke-GitHubCommand -Activity "Changing the issue's pinned state" -Arguments $arguments -Repository $Repository | Out-Null
        }
    }
}
