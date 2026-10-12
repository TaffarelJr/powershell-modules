function Unlock-GitHubPullRequest {
    <#
    .SYNOPSIS
        Unlocks a pull request's conversation.
    .DESCRIPTION
        Unlocks the conversation of a pull request, so that anyone who can
        see it may comment on it again. Lock-GitHubPullRequest locks it.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER PullRequest
        The pull request: its number or URL, or a pull request object. A
        branch name throws, as gh's unlock takes none.
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
        A pull request: its number or URL, or a pull request object such as
        Get-GitHubPullRequest returns. Binds to -PullRequest.
    .OUTPUTS
        None
    .EXAMPLE
        Unlock-GitHubPullRequest -PullRequest 42 -Repository 'OWNER/REPO'

        Unlocks the conversation of pull request 42 of OWNER/REPO.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Lock-GitHubPullRequest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

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
                NoBranch        = $true
            }
            $target = Resolve-GitHubPullRequestTarget @resolve
            $subject = Format-GitHubPullRequestTarget -Target $target -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($subject, 'Unlock pull request')) {
                return
            }

            $command = @{
                Activity   = "Unlocking $($target.Name)"
                Arguments  = @('pr', 'unlock') + $target.Arguments
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
