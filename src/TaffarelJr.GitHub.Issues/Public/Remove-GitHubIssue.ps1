function Remove-GitHubIssue {
    <#
    .SYNOPSIS
        Deletes an issue.
    .DESCRIPTION
        Deletes without asking by default; -Confirm asks first.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Issue
        The issue to delete: its number or URL, or an issue object. A pull
        request's URL or object is refused.
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
        The issue to delete, bound to -Issue: its number or URL, or an issue
        object, such as one a listing returned.
    .OUTPUTS
        None.
    .EXAMPLE
        Remove-GitHubIssue -Issue 12 -Repository OWNER/REPO

        Deletes issue 12 of OWNER/REPO. With -WhatIf it only says what it
        would delete.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/README.md
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Issue,

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
            if (-not $PSCmdlet.ShouldProcess($target, 'Delete issue')) {
                return
            }

            $invocation = @{
                Activity   = "Deleting issue $reference"
                Arguments  = @('issue', 'delete', $reference, '--yes')
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
