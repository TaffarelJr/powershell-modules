function Lock-GitHubIssue {
    <#
    .SYNOPSIS
        Locks an issue's conversation.
    .DESCRIPTION
        Locks the conversation of an issue, so that only collaborators can
        comment on it, with a reason if one is given. Unlock-GitHubIssue
        lifts the lock.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Issue
        The issue to lock: its number or URL, or an issue object. A pull
        request's URL or object is refused.
    .PARAMETER Reason
        Why it is locked: off_topic, resolved, spam, or too_heated, in any
        casing.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object. Omit it to use the current directory's
        repository; given as $null, it throws. An issue given by URL or
        object is in the repository it names; one in a different repository
        than this throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The issue to lock, bound to -Issue: its number or URL, or an issue
        object, such as one a listing returned.
    .OUTPUTS
        None.
    .EXAMPLE
        Lock-GitHubIssue -Issue 12 -Reason resolved -Repository OWNER/REPO

        Locks the conversation of issue 12 of OWNER/REPO as resolved.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/README.md
    .LINK
        Unlock-GitHubIssue
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Issue,

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
            $reference = Resolve-GitHubItemReference -Item $Issue -Kind Issue -Repository $repositoryReference
            $target = Format-GitHubIssueTarget -Reference $reference -Repository $repositoryReference
            $arguments = @('issue', 'lock', $reference)
            $action = 'Lock issue'
            if ($Reason) {
                $arguments += @('--reason', $Reason.ToLowerInvariant())
                $action += " ($($Reason.ToLowerInvariant()))"
            }

            if (-not $PSCmdlet.ShouldProcess($target, $action)) {
                return
            }

            $invocation = @{
                Activity   = "Locking issue $reference"
                Arguments  = $arguments
                Repository = $repositoryReference
            }
            Invoke-GitHubCommand @invocation | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
