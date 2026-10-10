function Remove-GitHubWorkflowRun {
    <#
    .SYNOPSIS
        Deletes a workflow run and its logs.
    .PARAMETER Id
        The run, by its database id.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [long]$Id,

        [string]$Repository
    )

    process {
        $arguments = @('run', 'delete', $Id)
        Invoke-GitHubCommand -Activity "Deleting workflow run $Id" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
