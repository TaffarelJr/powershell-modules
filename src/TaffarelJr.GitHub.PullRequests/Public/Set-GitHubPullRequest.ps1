function Set-GitHubPullRequest {
    <#
    .SYNOPSIS
        Changes a pull request's title, body, base, labels, people, or
        draft state.
    .DESCRIPTION
        Says what to change, or throws: asked for no change at all, gh
        would only refuse with a generic message. -Milestone with
        -RemoveMilestone throws too, as gh refuses the pair, and so do a
        blank -Title, -Base, or -Milestone, and a blank name in any list.
        The body reaches gh through a temporary file, so it arrives
        exactly as given.

        -Ready marks a draft ready for review, and -Ready:$false turns a
        pull request back into a draft. Along with other edits, that is a
        second gh call after the edit: if it fails, the edit stays made,
        and the error says so.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch, or a pull
        request object. Leave it out to use the current branch's pull
        request; with -Repository, gh still looks for that for an edit,
        but -Ready then throws, as gh needs the pull request named. Given
        as $null, it throws.
    .PARAMETER Title
        The new title. A blank one throws, as a pull request needs a
        title.
    .PARAMETER Body
        The new body, as Markdown. An empty string clears it.
    .PARAMETER Base
        The new base branch. A blank one throws.
    .PARAMETER Milestone
        The milestone to move the pull request to, by name. A blank one
        throws; -RemoveMilestone takes the pull request out of its
        milestone.
    .PARAMETER RemoveMilestone
        Takes the pull request out of its milestone. Given along with
        -Milestone, it throws. Needs gh 2.54 or later.
    .PARAMETER AddLabel
        Labels to add, by name.
    .PARAMETER RemoveLabel
        Labels to remove, by name.
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
        The repository, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object. Omit it to use the current directory's
        repository; given as $null, it throws. A pull request given by URL
        or object is in the repository it names; one in a different
        repository than this throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        A pull request: its number, URL, or head branch, or a pull request
        object such as Get-GitHubPullRequest returns. Binds to -PullRequest.
    .OUTPUTS
        None
    .EXAMPLE
        Set-GitHubPullRequest -PullRequest 42 -AddReviewer 'ORG/TEAM' -Ready `
            -Repository 'OWNER/REPO'

        Requests the team's review on draft pull request 42, then marks it
        ready for review - two gh calls, the second made only if the first
        succeeded.
    .EXAMPLE
        Set-GitHubPullRequest -PullRequest 42 -Title 'Add retry logic' `
            -AddLabel 'enhancement' -Repository 'OWNER/REPO'

        Retitles pull request 42 and labels it enhancement.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Get-GitHubPullRequest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

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

        [object]$Repository
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            if ($PSBoundParameters.ContainsKey('Milestone') -and $RemoveMilestone) {
                throw '-Milestone and -RemoveMilestone cannot be used together: one sets the milestone and the other' +
                ' removes it. Give only one.'
            }

            if ($PSBoundParameters.ContainsKey('Title') -and [string]::IsNullOrWhiteSpace($Title)) {
                throw '-Title is blank, and a pull request needs a title.'
            }

            if ($PSBoundParameters.ContainsKey('Base') -and [string]::IsNullOrWhiteSpace($Base)) {
                throw '-Base is blank, and a pull request needs a base branch.'
            }

            if ($PSBoundParameters.ContainsKey('Milestone') -and [string]::IsNullOrWhiteSpace($Milestone)) {
                throw '-Milestone is blank: use -RemoveMilestone to clear it.'
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $edits = @()
            if ($Title) {
                $edits += "--title=$Title"
            }

            if ($Base) {
                $edits += "--base=$Base"
            }

            if ($Milestone) {
                $edits += "--milestone=$Milestone"
            }

            if ($RemoveMilestone) {
                $edits += '--remove-milestone'
            }

            $lists = [ordered]@{
                AddLabel       = '--add-label'
                RemoveLabel    = '--remove-label'
                AddAssignee    = '--add-assignee'
                RemoveAssignee = '--remove-assignee'
                AddReviewer    = '--add-reviewer'
                RemoveReviewer = '--remove-reviewer'
                AddProject     = '--add-project'
                RemoveProject  = '--remove-project'
            }
            foreach ($name in $lists.Keys) {
                $convert = @{
                    Name  = $name
                    Flag  = $lists[$name]
                    Value = $PSBoundParameters[$name]
                }
                $edits += ConvertTo-GitHubPullRequestListArgument @convert
            }

            $changesBody = $PSBoundParameters.ContainsKey('Body')
            $changesReady = $PSBoundParameters.ContainsKey('Ready')
            if ($edits.Count -eq 0 -and -not $changesBody -and -not $changesReady) {
                throw 'Say what to change - for example -Title, -Body, -AddLabel, or -Ready.'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $resolve = @{
                BoundParameters = $PSBoundParameters
                Repository      = $repositoryReference
                AllowCurrent    = -not $changesReady
            }
            $target = Resolve-GitHubPullRequestTarget @resolve
            $subject = Format-GitHubPullRequestTarget -Target $target -Repository $repositoryReference
            $edited = $false
            if (($edits.Count -gt 0 -or $changesBody) -and $PSCmdlet.ShouldProcess($subject, 'Edit pull request')) {
                $command = @{
                    Activity   = "Editing $($target.Name)"
                    Arguments  = @('pr', 'edit') + $target.Arguments + $edits
                    Repository = $repositoryReference
                }
                if ($changesBody) {
                    $edit = {
                        param($File)

                        $command.Arguments = @('pr', 'edit') + $target.Arguments + @('--body-file', $File) + $edits
                        Invoke-GitHubCommand @command | Out-Null
                    }
                    Use-GitHubTextFile -Text $Body -ScriptBlock $edit
                }
                else {
                    Invoke-GitHubCommand @command | Out-Null
                }

                $edited = $true
            }

            if (-not $changesReady) {
                return
            }

            $arguments = @('pr', 'ready') + $target.Arguments
            $action = 'Mark pull request ready for review'
            if (-not $Ready) {
                $arguments += '--undo'
                $action = 'Convert pull request to a draft'
            }

            if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
                return
            }

            try {
                $command = @{
                    Activity   = "Changing the draft state of $($target.Name)"
                    Arguments  = $arguments
                    Repository = $repositoryReference
                }
                Invoke-GitHubCommand @command | Out-Null
            }
            catch {
                if (-not $edited) {
                    throw
                }

                $name = $target.Name.Substring(0, 1).ToUpperInvariant() + $target.Name.Substring(1)
                throw "$name was edited, but changing its draft state failed: $($_.Exception.Message)"
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
