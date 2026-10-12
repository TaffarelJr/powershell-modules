function Move-GitHubIssue {
    <#
    .SYNOPSIS
        Transfers an issue to another repository.
    .PARAMETER Issue
        The issue to transfer: its number or URL.
    .PARAMETER DestinationRepository
        The repository to transfer it to, in OWNER/REPO form.
    .PARAMETER Repository
        The issue's current repository, in [HOST/]OWNER/REPO form. Omit
        it to use the current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Number')]
        [string]$Issue,

        [Parameter(Mandatory, Position = 1)]
        [string]$DestinationRepository,

        [string]$Repository
    )

    process {
        $arguments = @('issue', 'transfer', $Issue, $DestinationRepository)
        Invoke-GitHubCommand -Activity "Transferring issue $Issue" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
