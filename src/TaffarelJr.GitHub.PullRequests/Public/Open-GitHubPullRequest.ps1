function Open-GitHubPullRequest {
    <#
    .SYNOPSIS
        Reopens a closed pull request.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch.
    .PARAMETER Comment
        A comment to leave while reopening.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$PullRequest,

        [string]$Comment,

        [string]$Repository
    )

    process {
        $arguments = @('pr', 'reopen', $PullRequest)
        if ($Comment) {
            $arguments += @('--comment', $Comment)
        }

        Invoke-GitHubCommand -Activity "Reopening pull request $PullRequest" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
