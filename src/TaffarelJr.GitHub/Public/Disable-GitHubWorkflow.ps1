function Disable-GitHubWorkflow {
    <#
    .SYNOPSIS
        Disables a workflow, so it neither runs nor shows up in listings.
    .PARAMETER Workflow
        The workflow, by id, name, or file name such as 'ci.yml'.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Path')]
        [string]$Workflow,

        [string]$Repository
    )

    process {
        $arguments = @('workflow', 'disable', $Workflow)
        Invoke-GitHubCommand -Activity "Disabling workflow $Workflow" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
