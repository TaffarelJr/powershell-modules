function Unlock-GitHubIssue {
    <#
    .SYNOPSIS
        Unlocks an issue's conversation.
    .PARAMETER Issue
        The issue to unlock: its number or URL.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Number')]
        [string]$Issue,

        [string]$Repository
    )

    process {
        $arguments = @('issue', 'unlock', $Issue)
        Invoke-GitHubCommand -Activity "Unlocking issue $Issue" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
