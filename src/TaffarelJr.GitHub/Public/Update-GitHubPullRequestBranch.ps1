function Update-GitHubPullRequestBranch {
    <#
    .SYNOPSIS
        Brings a pull request's head branch up to date with its base.
    .DESCRIPTION
        By default the base is merged into the head branch; -Rebase
        rebases the head onto the base instead.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch. Omit it to use
        the current branch's pull request.
    .PARAMETER Rebase
        Rebases onto the base branch instead of merging it in.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$PullRequest,

        [switch]$Rebase,

        [string]$Repository
    )

    $arguments = @('pr', 'update-branch')
    if ($PullRequest) {
        $arguments += $PullRequest
    }

    if ($Rebase) {
        $arguments += '--rebase'
    }

    Invoke-GitHubCommand -Activity 'Updating the pull request branch' -Arguments $arguments -Repository $Repository | Out-Null
}
