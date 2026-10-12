function Open-GitHubPullRequest {
    <#
    .SYNOPSIS
        Reopens a closed pull request.
    .DESCRIPTION
        Reopens a closed pull request, leaving a comment if one is given,
        so it can be reviewed and merged again. Close-GitHubPullRequest
        closes it once more.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch, or a pull
        request object.
    .PARAMETER Comment
        A comment to leave while reopening. A blank one throws.
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
        Open-GitHubPullRequest -PullRequest 42 `
            -Comment 'The fix was reverted.' -Repository 'OWNER/REPO'

        Reopens pull request 42 of OWNER/REPO with a comment.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Close-GitHubPullRequest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

        [string]$Comment,

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
            $arguments = @('pr', 'reopen') + $target.Arguments
            if ($Comment) {
                $arguments += "--comment=$Comment"
            }

            $subject = Format-GitHubPullRequestTarget -Target $target -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($subject, 'Reopen pull request')) {
                return
            }

            $command = @{
                Activity   = "Reopening $($target.Name)"
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
