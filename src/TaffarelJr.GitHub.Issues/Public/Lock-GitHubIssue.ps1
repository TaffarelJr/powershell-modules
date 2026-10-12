function Lock-GitHubIssue {
    <#
    .SYNOPSIS
        Locks an issue's conversation.
    .PARAMETER Issue
        The issue to lock: its number or URL.
    .PARAMETER Reason
        Why it is locked: off_topic, resolved, spam, or too_heated.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Number')]
        [string]$Issue,

        [ValidateSet('off_topic', 'resolved', 'spam', 'too_heated')]
        [string]$Reason,

        [string]$Repository
    )

    process {
        $arguments = @('issue', 'lock', $Issue)
        if ($Reason) {
            $arguments += @('--reason', $Reason)
        }

        Invoke-GitHubCommand -Activity "Locking issue $Issue" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
