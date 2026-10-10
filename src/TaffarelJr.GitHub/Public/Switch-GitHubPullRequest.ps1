function Switch-GitHubPullRequest {
    <#
    .SYNOPSIS
        Checks a pull request's head out as a local branch.
    .DESCRIPTION
        Works on the current directory's clone, the way gh pr checkout
        does: the pull request must be named, since gh would otherwise
        offer a picker it cannot show here.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch.
    .PARAMETER Branch
        The local branch name to use. gh's default is the head branch's
        own name.
    .PARAMETER Detach
        Checks the commit out with a detached HEAD instead of a branch.
    .PARAMETER Force
        Resets an existing local branch of that name to the pull
        request's latest state.
    .PARAMETER RecurseSubmodules
        Updates every submodule after the checkout.
    .PARAMETER Worktree
        Checks the pull request out into a new worktree at this path
        instead of switching the current one.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$PullRequest,

        [string]$Branch,

        [switch]$Detach,

        [switch]$Force,

        [switch]$RecurseSubmodules,

        [string]$Worktree,

        [string]$Repository
    )

    $arguments = @('pr', 'checkout', $PullRequest)
    if ($Branch) {
        $arguments += @('--branch', $Branch)
    }

    if ($Detach) {
        $arguments += '--detach'
    }

    if ($Force) {
        $arguments += '--force'
    }

    if ($RecurseSubmodules) {
        $arguments += '--recurse-submodules'
    }

    if ($Worktree) {
        $arguments += @('--worktree', $Worktree)
    }

    Invoke-GitHubCommand -Activity "Checking out pull request $PullRequest" -Arguments $arguments -Repository $Repository | Out-Null
}
