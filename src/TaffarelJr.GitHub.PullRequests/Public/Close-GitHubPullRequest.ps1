function Close-GitHubPullRequest {
    <#
    .SYNOPSIS
        Closes a pull request without merging it.
    .DESCRIPTION
        Closes an open pull request, leaving a comment and deleting its
        head branch if asked to. The pull request is not merged, and
        Open-GitHubPullRequest reopens it.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch, or a pull
        request object.
    .PARAMETER Comment
        A comment to leave while closing. A blank one throws.
    .PARAMETER DeleteBranch
        Deletes the head branch, locally and on GitHub, once closed.
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
        Close-GitHubPullRequest -PullRequest 42 -DeleteBranch `
            -Repository 'OWNER/REPO'

        Closes pull request 42 of OWNER/REPO without merging it, and
        deletes its head branch.
    .EXAMPLE
        Get-GitHubPullRequest -List -Label 'stale' -Repository 'OWNER/REPO' |
            Close-GitHubPullRequest -Comment 'Closing as stale.'

        Closes every open pull request labeled stale, leaving a comment on
        each, in the repository its listing came from.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Open-GitHubPullRequest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

        [string]$Comment,

        [switch]$DeleteBranch,

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

            if ($PSBoundParameters.ContainsKey('Comment') -and [string]::IsNullOrWhiteSpace($Comment)) {
                throw "-Comment is blank: give the comment's text, or leave it out."
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
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
            }
            $target = Resolve-GitHubPullRequestTarget @resolve
            $arguments = @('pr', 'close') + $target.Arguments
            if ($Comment) {
                $arguments += "--comment=$Comment"
            }

            $action = 'Close pull request'
            if ($DeleteBranch) {
                $arguments += '--delete-branch'
                $action += ', deleting the head branch'
            }

            $subject = Format-GitHubPullRequestTarget -Target $target -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
                return
            }

            $command = @{
                Activity   = "Closing $($target.Name)"
                Arguments  = $arguments
                Repository = $repositoryReference
            }
            Invoke-GitHubCommand @command | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
