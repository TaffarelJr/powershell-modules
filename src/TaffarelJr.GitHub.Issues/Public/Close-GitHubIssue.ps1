function Close-GitHubIssue {
    <#
    .SYNOPSIS
        Closes an issue.
    .PARAMETER Issue
        The issue to close: its number or URL.
    .PARAMETER Comment
        A comment to leave while closing.
    .PARAMETER Reason
        Why it is closing: completed, 'not planned', or duplicate.
    .PARAMETER DuplicateOf
        With -Reason duplicate, the issue it duplicates, by number or
        URL.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Number')]
        [string]$Issue,

        [string]$Comment,

        [ValidateSet('completed', 'not planned', 'duplicate')]
        [string]$Reason,

        [string]$DuplicateOf,

        [string]$Repository
    )

    process {
        $arguments = @('issue', 'close', $Issue)
        if ($Comment) {
            $arguments += @('--comment', $Comment)
        }

        if ($Reason) {
            $arguments += @('--reason', $Reason)
        }

        if ($DuplicateOf) {
            $arguments += @('--duplicate-of', $DuplicateOf)
        }

        Invoke-GitHubCommand -Activity "Closing issue $Issue" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
