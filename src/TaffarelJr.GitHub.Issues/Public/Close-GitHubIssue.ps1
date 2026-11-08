function Close-GitHubIssue {
    <#
    .SYNOPSIS
        Closes an issue.
    .DESCRIPTION
        An issue that is already closed is left as it is, and gh says so
        without failing - and without leaving -Comment or checking
        -DuplicateOf. -DuplicateOf alone closes it as a duplicate; with
        any other -Reason, gh refuses.

        gh takes the closing comment on its command line, not from a file
        as Add-GitHubIssueComment's is. On Windows a command line holds at
        most 32,767 characters, so for a longer comment, post it with
        Add-GitHubIssueComment and then close the issue without one.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Issue
        The issue to close: its number or URL, or an issue object. A pull
        request's URL or object is refused.
    .PARAMETER Comment
        A comment to leave while closing. A blank one throws.
    .PARAMETER Reason
        Why it is closing: completed, 'not planned', or duplicate, in any
        casing. Closing as a duplicate needs gh 2.88 or later.
    .PARAMETER DuplicateOf
        The issue this one duplicates: its number or URL, or an issue
        object. Needs gh 2.88 or later.
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
        The issue to close, bound to -Issue: its number or URL, or an issue
        object, such as one a listing returned.
    .OUTPUTS
        None.
    .EXAMPLE
        Close-GitHubIssue -Issue 12 -Reason completed -Repository OWNER/REPO

        Closes issue 12 of OWNER/REPO as completed.
    .EXAMPLE
        Get-GitHubIssue -List -Label stale -Repository OWNER/REPO |
            Close-GitHubIssue -Reason 'not planned'

        Closes every open issue of OWNER/REPO labeled stale, as not planned.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/README.md
    .LINK
        Open-GitHubIssue
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Issue,

        [string]$Comment,

        [ValidateSet('completed', 'not planned', 'duplicate')]
        [string]$Reason,

        [object]$DuplicateOf,

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
            $options = @()
            if ($Comment) {
                $options += "--comment=$Comment"
            }

            if ($Reason) {
                $options += @('--reason', $Reason.ToLowerInvariant())
            }

            if ($PSBoundParameters.ContainsKey('DuplicateOf')) {
                $original = Resolve-GitHubItemReference -Item $DuplicateOf -Kind Issue -NotPiped
                $options += @('--duplicate-of', $original)
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
            $reference = Resolve-GitHubItemReference -Item $Issue -Kind Issue -Repository $repositoryReference
            $target = Format-GitHubIssueTarget -Reference $reference -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($target, 'Close issue')) {
                return
            }

            $invocation = @{
                Activity   = "Closing issue $reference"
                Arguments  = @('issue', 'close', $reference) + $options
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
