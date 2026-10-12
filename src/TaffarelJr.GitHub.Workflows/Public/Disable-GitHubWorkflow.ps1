function Disable-GitHubWorkflow {
    <#
    .SYNOPSIS
        Disables a workflow, so it no longer runs.
    .DESCRIPTION
        A disabled workflow keeps its runs and stays visible on GitHub
        and in Get-GitHubWorkflow -All, but gh's default workflow listing
        leaves it out.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Workflow
        The workflow, by id, name, or file name such as 'ci.yml', or an
        object piped in: a workflow from Get-GitHubWorkflow, read by its
        Id, or a run from Get-GitHubWorkflowRun, read by its
        WorkflowDatabaseId.
    .PARAMETER Repository
        The repository, as [HOST/]OWNER/REPO, a URL, or a repository
        object. A workflow piped in is acted on where it came from - its
        Repository - and a -Repository that names another repository
        throws. Omit both to use the current directory's repository; a
        -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        A workflow, by id, name, or file name, or a workflow object such as
        Get-GitHubWorkflow returns. Binds to -Workflow; a Repository property,
        when the object has one, binds to -Repository.
    .OUTPUTS
        None
    .EXAMPLE
        Disable-GitHubWorkflow -Workflow 'ci.yml' -Repository 'OWNER/REPO'

        Disables the ci.yml workflow of OWNER/REPO.
    .EXAMPLE
        Get-GitHubWorkflow -Repository 'OWNER/REPO' |
            Where-Object Name -Like 'Nightly*' |
            Disable-GitHubWorkflow

        Disables every workflow whose name starts with Nightly, each in
        the repository it was listed from.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Enable-GitHubWorkflow
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Workflow,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$Repository
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            Resolve-GitHubRepositoryArgument -Value $Repository -Given $PSBoundParameters.ContainsKey('Repository') |
                Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $reference = ConvertTo-GitHubWorkflowReference -Workflow $Workflow
            $repositoryReference = Resolve-GitHubOriginRepository -Repository $Repository -InputObject $Workflow `
                -Item "Workflow $reference"
            $target = Format-GitHubItemTarget -Repository $repositoryReference -Item "workflow $reference"
            if (-not $PSCmdlet.ShouldProcess($target, 'Disable workflow')) {
                return
            }

            $arguments = @('workflow', 'disable', '--', $reference)
            $activity = "Disabling workflow $reference"
            Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $repositoryReference | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
