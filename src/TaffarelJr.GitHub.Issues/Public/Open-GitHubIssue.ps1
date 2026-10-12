function Open-GitHubIssue {
    <#
    .SYNOPSIS
        Reopens a closed issue.
    .PARAMETER Issue
        The issue to reopen: its number or URL.
    .PARAMETER Comment
        A comment to leave while reopening.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Number')]
        [string]$Issue,

        [string]$Comment,

        [string]$Repository
    )

    process {
        $arguments = @('issue', 'reopen', $Issue)
        if ($Comment) {
            $arguments += @('--comment', $Comment)
        }

        Invoke-GitHubCommand -Activity "Reopening issue $Issue" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
