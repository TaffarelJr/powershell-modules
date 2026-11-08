function Submit-GitHubPullRequestReview {
    <#
    .SYNOPSIS
        Reviews a pull request: approves it, requests changes, or
        comments.
    .DESCRIPTION
        The review body reaches gh through a temporary file, so it arrives
        exactly as given. GitHub requires a body for a comment or a change
        request; an approval may go without one.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch, or a pull
        request object. Leave it out to use the current branch's pull
        request, which works only without -Repository: gh needs the pull
        request named along with it. Given as $null, it throws.
    .PARAMETER Decision
        The review's verdict: Approve, RequestChanges, or Comment.
    .PARAMETER Body
        The review's text.
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
        Submit-GitHubPullRequestReview -PullRequest 42 -Decision Approve `
            -Repository 'OWNER/REPO'

        Approves pull request 42 of OWNER/REPO.
    .EXAMPLE
        Submit-GitHubPullRequestReview -PullRequest 42 `
            -Decision RequestChanges -Body 'Please test the retry path.'

        Requests changes on pull request 42, saying what is needed.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Add-GitHubPullRequestComment
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

        [Parameter(Mandatory)]
        [ValidateSet('Approve', 'RequestChanges', 'Comment')]
        [string]$Decision,

        [string]$Body,

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

            $given = $PSBoundParameters.ContainsKey('Repository')
            $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $flags = @{
                Approve        = '--approve'
                RequestChanges = '--request-changes'
                Comment        = '--comment'
            }
            $actions = @{
                Approve        = 'Approve pull request'
                RequestChanges = 'Request changes on pull request'
                Comment        = 'Comment on pull request in a review'
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
            }
            $target = Resolve-GitHubPullRequestTarget @resolve
            $subject = Format-GitHubPullRequestTarget -Target $target -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($subject, $actions[$Decision])) {
                return
            }

            $command = @{
                Activity   = "Reviewing $($target.Name)"
                Arguments  = @('pr', 'review') + $target.Arguments + $flags[$Decision]
                Repository = $repositoryReference
            }
            if (-not $PSBoundParameters.ContainsKey('Body')) {
                Invoke-GitHubCommand @command | Out-Null
                return
            }

            $review = {
                param($File)

                $command.Arguments += @('--body-file', $File)
                Invoke-GitHubCommand @command | Out-Null
            }
            Use-GitHubTextFile -Text $Body -ScriptBlock $review
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
