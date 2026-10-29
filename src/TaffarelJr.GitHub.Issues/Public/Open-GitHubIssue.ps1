function Open-GitHubIssue {
    <#
    .SYNOPSIS
        Reopens a closed issue.
    .DESCRIPTION
        gh takes the reopening comment on its command line, not from a
        file as Add-GitHubIssueComment's is. On Windows a command line
        holds at most 32,767 characters, so for a longer comment, reopen
        the issue without one and post it with Add-GitHubIssueComment.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Issue
        The issue to reopen: its number or URL, or an issue object. A pull
        request's URL or object is refused.
    .PARAMETER Comment
        A comment to leave while reopening. A blank one throws.
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
        The issue to reopen, bound to -Issue: its number or URL, or an issue
        object, such as one a listing returned.
    .OUTPUTS
        None.
    .EXAMPLE
        Open-GitHubIssue -Issue 12 -Comment 'Reopening.' -Repository OWNER/REPO

        Reopens issue 12 of OWNER/REPO with a comment.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/README.md
    .LINK
        Close-GitHubIssue
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Issue,

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
            $reference = Resolve-GitHubItemReference -Item $Issue -Kind Issue -Repository $repositoryReference
            $target = Format-GitHubIssueTarget -Reference $reference -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($target, 'Reopen issue')) {
                return
            }

            $arguments = @('issue', 'reopen', $reference)
            if ($Comment) {
                $arguments += "--comment=$Comment"
            }

            $invocation = @{
                Activity   = "Reopening issue $reference"
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
