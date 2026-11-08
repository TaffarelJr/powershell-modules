function Update-GitHubPullRequestBranch {
    <#
    .SYNOPSIS
        Brings a pull request's head branch up to date with its base.
    .DESCRIPTION
        By default the base is merged into the head branch; -Rebase
        rebases the head onto the base instead. Needs gh 2.53 or later.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch, or a pull
        request object. Leave it out to use the current branch's pull
        request, which works only without -Repository: gh needs the pull
        request named along with it. Given as $null, it throws.
    .PARAMETER Rebase
        Rebases onto the base branch instead of merging it in.
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
        Update-GitHubPullRequestBranch -PullRequest 42 -Rebase `
            -Repository 'OWNER/REPO'

        Rebases the head branch of pull request 42 onto its base branch.
    .EXAMPLE
        Get-GitHubPullRequest -List -Label 'needs-update' |
            Update-GitHubPullRequestBranch

        Merges the base branch into the head branch of every open pull
        request labeled needs-update.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Get-GitHubPullRequest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

        [switch]$Rebase,

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
            $arguments = @('pr', 'update-branch') + $target.Arguments
            $action = 'Merge the base branch into the head branch'
            if ($Rebase) {
                $arguments += '--rebase'
                $action = 'Rebase the head branch onto the base branch'
            }

            $subject = Format-GitHubPullRequestTarget -Target $target -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
                return
            }

            $command = @{
                Activity   = "Updating the branch of $($target.Name)"
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
