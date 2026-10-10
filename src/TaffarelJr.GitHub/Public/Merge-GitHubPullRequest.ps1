function Merge-GitHubPullRequest {
    <#
    .SYNOPSIS
        Merges a pull request, or arranges for it to merge once its
        requirements are met.
    .DESCRIPTION
        Without -Strategy, gh uses the repository's only allowed merge
        method, or fails if there is more than one to choose from - it
        cannot prompt here. The commit body travels to gh on standard
        input, so a multi-line body arrives intact.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch. Omit it to use
        the current branch's pull request.
    .PARAMETER Strategy
        How to merge: merge, squash, or rebase.
    .PARAMETER Subject
        The merge commit's subject line.
    .PARAMETER Body
        The merge commit's body.
    .PARAMETER AuthorEmail
        The merge commit's author email.
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
        Merges only if the head is still this commit SHA.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$PullRequest,

        [ValidateSet('merge', 'squash', 'rebase')]
        [string]$Strategy,

        [string]$Subject,

        [string]$Body,

        [string]$AuthorEmail,

        [switch]$DeleteBranch,

        [switch]$Auto,

        [switch]$DisableAuto,

        [switch]$Admin,

        [string]$MatchHeadCommit,

        [string]$Repository
    )

    $arguments = @('pr', 'merge')
    if ($PullRequest) {
        $arguments += $PullRequest
    }

    if ($Strategy) {
        $arguments += "--$Strategy"
    }

    if ($Subject) {
        $arguments += @('--subject', $Subject)
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $arguments += @('--body-file', '-')
    }

    if ($AuthorEmail) {
        $arguments += @('--author-email', $AuthorEmail)
    }

    if ($DeleteBranch) {
        $arguments += '--delete-branch'
    }

    if ($Auto) {
        $arguments += '--auto'
    }

    if ($DisableAuto) {
        $arguments += '--disable-auto'
    }

    if ($Admin) {
        $arguments += '--admin'
    }

    if ($MatchHeadCommit) {
        $arguments += @('--match-head-commit', $MatchHeadCommit)
    }

    $extra = @{}
    if ($PSBoundParameters.ContainsKey('Body')) {
        $extra['StdIn'] = $Body
    }

    Invoke-GitHubCommand -Activity 'Merging the pull request' -Arguments $arguments -Repository $Repository @extra | Out-Null
}
