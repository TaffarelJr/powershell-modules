function Merge-GitHubPullRequest {
    <#
    .SYNOPSIS
        Merges a pull request, or arranges for it to merge once its
        requirements are met.
    .DESCRIPTION
        gh cannot ask which way to merge here, so it needs -Strategy -
        and fails saying so without one - unless the base branch uses a
        merge queue, which sets the method itself. The commit body reaches
        gh through a temporary file, so it arrives exactly as given.

        -Auto, -DisableAuto and -Admin are alternatives to merging now,
        and only one of them can be given.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch, or a pull
        request object. Leave it out to use the current branch's pull
        request, which works only without -Repository: gh needs the pull
        request named along with it. Given as $null, it throws.
    .PARAMETER Strategy
        How to merge: merge, squash, or rebase.
    .PARAMETER Subject
        The merge commit's subject line. A blank one throws.
    .PARAMETER Body
        The merge commit's body. An empty one is a body too.
    .PARAMETER AuthorEmail
        The merge commit's author email. A blank one throws.
    .PARAMETER DeleteBranch
        Deletes the head branch, locally and on GitHub, once merged.
    .PARAMETER Auto
        Enables auto-merge: the pull request merges itself once every
        requirement is met.
    .PARAMETER DisableAuto
        Turns auto-merge off for the pull request instead.
    .PARAMETER Admin
        Uses administrator privileges to merge a pull request that does
        not meet the branch's requirements, bypassing a merge queue.
    .PARAMETER MatchHeadCommit
        Merges only if the head is still this commit SHA. A blank one
        throws, rather than merging unchecked.
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
        Merge-GitHubPullRequest -PullRequest 42 -Strategy squash `
            -Repository 'OWNER/REPO'

        Squash-merges pull request 42 of OWNER/REPO now.
    .EXAMPLE
        Get-GitHubPullRequest -List -Author 'app/dependabot' -Limit 1000 `
            -Property number -Repository 'OWNER/REPO' |
            Merge-GitHubPullRequest -Strategy squash -Auto -DeleteBranch -WhatIf

        Shows which open Dependabot pull requests of OWNER/REPO - up to
        1000, where gh's default lists the first 30 - would be set to
        squash-merge themselves once their checks pass, each in the
        repository its listing came from. Without -WhatIf it sets them.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Close-GitHubPullRequest
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Now')]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

        [ValidateSet('merge', 'squash', 'rebase')]
        [string]$Strategy,

        [string]$Subject,

        [string]$Body,

        [string]$AuthorEmail,

        [switch]$DeleteBranch,

        [Parameter(ParameterSetName = 'Auto')]
        [switch]$Auto,

        [Parameter(ParameterSetName = 'DisableAuto')]
        [switch]$DisableAuto,

        [Parameter(ParameterSetName = 'Admin')]
        [switch]$Admin,

        [string]$MatchHeadCommit,

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

            if ($PSBoundParameters.ContainsKey('MatchHeadCommit') -and [string]::IsNullOrWhiteSpace($MatchHeadCommit)) {
                throw '-MatchHeadCommit was given but is blank, so the merge would not be checked against any commit.' +
                ' Give the SHA, or leave -MatchHeadCommit off.'
            }

            $blanks = [ordered]@{
                Subject     = 'the subject line'
                AuthorEmail = 'an email address'
            }
            foreach ($name in $blanks.Keys) {
                if ($PSBoundParameters.ContainsKey($name) -and
                    [string]::IsNullOrWhiteSpace($PSBoundParameters[$name])) {
                    throw "-$name is blank: give $($blanks[$name]), or leave it out."
                }
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
            $before = @('pr', 'merge') + $target.Arguments
            if ($Strategy) {
                $before += "--$($Strategy.ToLowerInvariant())"
            }

            if ($Subject) {
                $before += "--subject=$Subject"
            }

            $after = @()
            if ($AuthorEmail) {
                $after += "--author-email=$AuthorEmail"
            }

            if ($DeleteBranch) {
                $after += '--delete-branch'
            }

            if ($Auto) {
                $after += '--auto'
            }

            if ($DisableAuto) {
                $after += '--disable-auto'
            }

            if ($Admin) {
                $after += '--admin'
            }

            if ($MatchHeadCommit) {
                $after += "--match-head-commit=$MatchHeadCommit"
            }

            $action = 'Merge pull request'
            if ($Auto) {
                $action = 'Enable auto-merge'
            }

            if ($DisableAuto) {
                $action = 'Disable auto-merge'
            }

            if ($Admin) {
                $action = 'Merge pull request with administrator privileges'
            }

            if ($Strategy) {
                $action += " ($($Strategy.ToLowerInvariant()))"
            }

            if ($DeleteBranch) {
                $action += ', deleting the head branch'
            }

            $subject = Format-GitHubPullRequestTarget -Target $target -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($subject, $action)) {
                return
            }

            $command = @{
                Activity   = "Merging $($target.Name)"
                Arguments  = $before + $after
                Repository = $repositoryReference
            }
            if (-not $PSBoundParameters.ContainsKey('Body')) {
                Invoke-GitHubCommand @command | Out-Null
                return
            }

            $merge = {
                param($File)

                $command.Arguments = $before + @('--body-file', $File) + $after
                Invoke-GitHubCommand @command | Out-Null
            }
            Use-GitHubTextFile -Text $Body -ScriptBlock $merge
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
