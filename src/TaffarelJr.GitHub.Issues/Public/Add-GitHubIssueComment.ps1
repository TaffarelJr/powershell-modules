function Add-GitHubIssueComment {
    <#
    .SYNOPSIS
        Comments on an issue, or edits the authenticated user's last
        comment there.
    .DESCRIPTION
        The comment reaches gh through a temporary file, so it arrives
        exactly as given: any length, line endings as they are, and nothing
        added at the end.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Issue
        The issue to comment on: its number or URL, or an issue object. A
        pull request's URL or object is refused.
    .PARAMETER Body
        The comment's text, as Markdown. A blank one throws, as GitHub
        refuses an empty comment.
    .PARAMETER EditLast
        Replaces the authenticated user's most recent comment instead of
        adding a new one.
    .PARAMETER CreateIfNone
        With -EditLast, adds a new comment when there is none to edit.
        Without -EditLast it throws, as gh refuses it. Needs gh 2.68 or
        later.
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
        The issue to comment on, bound to -Issue: its number or URL, or an
        issue object.
    .OUTPUTS
        None.
    .EXAMPLE
        Add-GitHubIssueComment -Issue 12 -Body 'Fixed.' -Repository OWNER/REPO

        Adds a comment to issue 12 of OWNER/REPO.
    .EXAMPLE
        Add-GitHubIssueComment -Issue 12 -Body 'Still open.' -EditLast

        Replaces the authenticated user's last comment on issue 12, in the
        current directory's repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/README.md
    .LINK
        Get-GitHubIssue
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Issue,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Body,

        [switch]$EditLast,

        [switch]$CreateIfNone,

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

            if ($CreateIfNone -and -not $EditLast) {
                throw '-CreateIfNone works only with -EditLast: it adds a comment when there is no last one to edit.' +
                ' Give -EditLast too, or leave -CreateIfNone off.'
            }

            if ([string]::IsNullOrWhiteSpace($Body)) {
                throw '-Body is blank, and GitHub refuses an empty comment. Give the text.'
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $options = @()
            $action = 'Add comment'
            if ($EditLast) {
                $options += '--edit-last'
                $action = 'Edit last comment'
            }

            if ($CreateIfNone) {
                $options += '--create-if-none'
                $action = 'Edit last comment, or add one'
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
            if (-not $PSCmdlet.ShouldProcess($target, $action)) {
                return
            }

            Use-GitHubTextFile -Text $Body -ScriptBlock {
                param($Path)

                $invocation = @{
                    Activity   = "Commenting on issue $reference"
                    Arguments  = @('issue', 'comment', $reference, '--body-file', $Path) + $options
                    Repository = $repositoryReference
                }
                Invoke-GitHubCommand @invocation | Out-Null
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
