function Start-GitHubWorkflow {
    <#
    .SYNOPSIS
        Dispatches a workflow that has a workflow_dispatch trigger.
    .DESCRIPTION
        Inputs are sent as strings, which is all a workflow_dispatch
        input ever is. gh prints the new run's URL when GitHub reports
        one; it does not always.
    .PARAMETER Workflow
        The workflow, by id, name, or file name such as 'ci.yml'.
    .PARAMETER Ref
        The branch or tag whose version of the workflow file to run.
        Omit it for the default branch.
    .PARAMETER Inputs
        The workflow's inputs, keyed by name.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form. Omit it to use the
        current directory's repository.
    .OUTPUTS
        The new run's URL when gh reports one, otherwise nothing.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('Path')]
        [string]$Workflow,

        [string]$Ref,

        [hashtable]$Inputs,

        [string]$Repository
    )

    process {
        $arguments = @('workflow', 'run', $Workflow)
        if ($Ref) {
            $arguments += @('--ref', $Ref)
        }

        $arguments += ConvertTo-GitHubFieldArgument -Flag '--raw-field' -Fields $Inputs
        $out = Invoke-GitHubCommand -Activity "Dispatching workflow $Workflow" -Arguments $arguments -Repository $Repository
        return $out | Where-Object { $_ -match '^https?://' } | Select-Object -First 1
    }
}
