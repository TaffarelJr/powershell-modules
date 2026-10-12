function Stop-GitHubWorkflowRun {
    <#
    .SYNOPSIS
        Cancels a workflow run.
    .PARAMETER Id
        The run, by its database id.
    .PARAMETER Force
        Force-cancels a run that a normal cancel leaves hanging.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [long]$Id,

        [switch]$Force,

        [string]$Repository
    )

    process {
        $arguments = @('run', 'cancel', $Id)
        if ($Force) {
            $arguments += '--force'
        }

        Invoke-GitHubCommand -Activity "Cancelling workflow run $Id" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
