function Close-GitHubPullRequest {
    <#
    .SYNOPSIS
        Closes a pull request without merging it.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch.
    .PARAMETER Comment
        A comment to leave while closing.
    .PARAMETER DeleteBranch
        Deletes the head branch, locally and on GitHub, once closed.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$PullRequest,

        [string]$Comment,

        [switch]$DeleteBranch,

        [string]$Repository
    )

    process {
        $arguments = @('pr', 'close', $PullRequest)
        if ($Comment) {
            $arguments += @('--comment', $Comment)
        }

        if ($DeleteBranch) {
            $arguments += '--delete-branch'
        }

        Invoke-GitHubCommand -Activity "Closing pull request $PullRequest" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
