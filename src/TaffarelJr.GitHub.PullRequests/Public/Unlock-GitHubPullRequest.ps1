function Unlock-GitHubPullRequest {
    <#
    .SYNOPSIS
        Unlocks a pull request's conversation.
    .PARAMETER PullRequest
        The pull request: its number or URL.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$PullRequest,

        [string]$Repository
    )

    process {
        $arguments = @('pr', 'unlock', $PullRequest)
        Invoke-GitHubCommand -Activity "Unlocking pull request $PullRequest" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
