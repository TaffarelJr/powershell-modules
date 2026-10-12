function Remove-GitHubIssue {
    <#
    .SYNOPSIS
        Deletes an issue.
    .PARAMETER Issue
        The issue to delete: its number or URL.
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
        $arguments = @('issue', 'delete', $Issue, '--yes')
        Invoke-GitHubCommand -Activity "Deleting issue $Issue" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
