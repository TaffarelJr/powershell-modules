function Enable-GitHubWorkflow {
    <#
    .SYNOPSIS
        Enables a workflow, so it runs again and shows up in listings.
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
        $arguments = @('workflow', 'enable', $Workflow)
        Invoke-GitHubCommand -Activity "Enabling workflow $Workflow" -Arguments $arguments -Repository $Repository | Out-Null
    }
}
