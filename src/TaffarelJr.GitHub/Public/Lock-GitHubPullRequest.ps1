function Lock-GitHubPullRequest {
    <#
    .SYNOPSIS
        Locks a pull request's conversation.
    .PARAMETER PullRequest
        The pull request: its number or URL.
    .PARAMETER Reason
        Why it is locked: off_topic, resolved, spam, or too_heated.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$PullRequest,

        [ValidateSet('off_topic', 'resolved', 'spam', 'too_heated')]
        [string]$Reason,

        [string]$Repository
    )

    process {
        $arguments = @('pr', 'lock', $PullRequest)
        if ($Reason) {
            $arguments += @('--reason', $Reason)
        }

        Invoke-GitHubCommand -Activity "Locking pull request $PullRequest" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
