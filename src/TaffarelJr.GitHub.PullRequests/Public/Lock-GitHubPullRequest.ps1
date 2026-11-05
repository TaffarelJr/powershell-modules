function Lock-GitHubPullRequest {
    <#
    .SYNOPSIS
        Locks a pull request's conversation.
    .DESCRIPTION
        Locks the conversation of a pull request, so that only
        collaborators can comment on it, with a reason if one is given.
        Unlock-GitHubPullRequest lifts the lock.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER PullRequest
        The pull request: its number or URL, or a pull request object. A
        branch name throws, as gh's lock takes none.
    .PARAMETER Reason
        Why it is locked: off_topic, resolved, spam, or too_heated, in any
        casing.
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
        Lock-GitHubPullRequest -PullRequest 42 -Reason resolved `
            -Repository 'OWNER/REPO'

        Locks the conversation of pull request 42 as resolved.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Unlock-GitHubPullRequest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

        [ValidateSet('off_topic', 'resolved', 'spam', 'too_heated')]
        [string]$Reason,

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
            $arguments = @('pr', 'lock') + $target.Arguments
            $action = 'Lock pull request'
            if ($Reason) {
                $arguments += @('--reason', $Reason.ToLowerInvariant())
                $action += " ($($Reason.ToLowerInvariant()))"
            }

            $subject = Format-GitHubPullRequestTarget -Target $target -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
                return
            }

            $command = @{
                Activity   = "Locking $($target.Name)"
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
