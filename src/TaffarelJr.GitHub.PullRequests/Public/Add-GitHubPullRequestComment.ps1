function Add-GitHubPullRequestComment {
    <#
    .SYNOPSIS
        Comments on a pull request, or edits the authenticated user's
        last comment there.
    .DESCRIPTION
        The comment reaches gh through a temporary file, so it arrives
        exactly as given - every line ending kept, nothing added - and
        never appears in a failure message.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch, or a pull
        request object. Leave it out to use the current branch's pull
        request, which works only without -Repository: gh needs the pull
        request named along with it. Given as $null, it throws.
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
        Add-GitHubPullRequestComment -PullRequest 42 `
            -Body 'Rebased onto main.' -Repository 'OWNER/REPO'

        Comments on pull request 42 of OWNER/REPO.
    .EXAMPLE
        Add-GitHubPullRequestComment -EditLast -CreateIfNone `
            -Body 'Build 1234 passed.'

        Replaces the user's last comment on the current branch's pull
        request with this one, or adds the comment when there is none.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Get-GitHubPullRequest
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

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
            if ($EditLast) {
                $options += '--edit-last'
            }

            if ($CreateIfNone) {
                $options += '--create-if-none'
            }

            $action = 'Add comment'
            if ($EditLast) {
                $action = 'Edit last comment'
            }

            if ($CreateIfNone) {
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
            $resolve = @{
                BoundParameters = $PSBoundParameters
                Repository      = $repositoryReference
            }
            $target = Resolve-GitHubPullRequestTarget @resolve
            $subject = Format-GitHubPullRequestTarget -Target $target -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
                return
            }

            $comment = {
                param($File)

                $command = @{
                    Activity   = "Commenting on $($target.Name)"
                    Arguments  = @('pr', 'comment') + $target.Arguments + @('--body-file', $File) + $options
                    Repository = $repositoryReference
                }
                Invoke-GitHubCommand @command | Out-Null
            }
            Use-GitHubTextFile -Text $Body -ScriptBlock $comment
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
