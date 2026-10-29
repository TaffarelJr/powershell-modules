function Stop-GitHubWorkflowRun {
    <#
    .SYNOPSIS
        Cancels a workflow run.
    .DESCRIPTION
        Runs gh run cancel, which asks GitHub to cancel the run. A run
        piped in from Get-GitHubWorkflowRun is cancelled where it came
        from; -Force asks for a force-cancel of a run that a normal cancel
        leaves hanging.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER RunId
        The run, by its database id. A run piped in binds by its
        DatabaseId; a job, or any other object whose Url is not that run's,
        is refused.
    .PARAMETER Force
        Force-cancels a run that a normal cancel leaves hanging. Needs gh
        2.78 or later.
    .PARAMETER Repository
        The repository, as [HOST/]OWNER/REPO, a URL, or a repository
        object. A run piped in is acted on where it came from - its
        Repository, else its Url - and a -Repository that names another
        repository throws. Omit both to use the current directory's
        repository; a -Repository given as $null throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Int64
        A run id, or a workflow run object such as Get-GitHubWorkflowRun
        returns, whose DatabaseId binds to -RunId. A Repository property,
        when the object has one, binds to -Repository.
    .OUTPUTS
        None
    .EXAMPLE
        Stop-GitHubWorkflowRun -RunId 123456789 -Repository 'OWNER/REPO'

        Cancels run 123456789 of OWNER/REPO.
    .EXAMPLE
        Get-GitHubWorkflowRun -List -Workflow 'ci.yml' -Status in_progress |
            Stop-GitHubWorkflowRun

        Cancels every run of ci.yml that is still going.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Restart-GitHubWorkflowRun
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$RunId,

        [switch]$Force,

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
            $piped = if ($MyInvocation.ExpectingInput) { $_ } else { $null }
            $repositoryReference = Resolve-GitHubRunRepository -InputObject $piped -RunId $RunId `
                -Repository $Repository `
                -Advice 'Give the run it belongs to.'
            $arguments = @('run', 'cancel', $RunId)
            if ($Force) {
                $arguments += '--force'
            }

            $action = if ($Force) { 'Force-cancel workflow run' } else { 'Cancel workflow run' }
            $target = Format-GitHubItemTarget -Repository $repositoryReference -Item "workflow run $RunId"
            if (-not $PSCmdlet.ShouldProcess($target, $action)) {
                return
            }

            $activity = "Canceling workflow run $RunId"
            Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $repositoryReference | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
