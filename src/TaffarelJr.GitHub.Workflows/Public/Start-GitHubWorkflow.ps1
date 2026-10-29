function Start-GitHubWorkflow {
    <#
    .SYNOPSIS
        Dispatches a workflow that has a workflow_dispatch trigger, and
        returns the run it started where gh reports it.
    .DESCRIPTION
        Inputs are sent as strings, which is all a workflow_dispatch
        input ever is: a bool or a switch goes as true or false, and $null
        as an empty string. They go to gh as one JSON object on its
        standard input, so none appears in a command line, in -Verbose
        output, or in an error message, and a large one cannot overrun the
        command line's limit.

        gh 2.87 and later asks GitHub for the new run and prints its URL,
        which carries the run's id, so the run is known with no guessing.
        An older gh, or a GitHub that does not return the run (an older
        GitHub Enterprise Server), prints nothing: then Url and DatabaseId
        are both $null, and Wait-GitHubWorkflowRunStart finds the run by
        polling instead.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Workflow
        The workflow, by id, name, or file name such as 'ci.yml', or a
        workflow object piped in from Get-GitHubWorkflow, read by its Id.
        gh reads a value that is all digits as an id and one that ends
        in .yml or .yaml as a file name, and matches anything else
        against the workflows' names - so a workflow whose name looks
        like either is named by its id.
    .PARAMETER Ref
        The branch or tag whose version of the workflow file to run.
        Omit it for the default branch; a blank value is refused.
    .PARAMETER Inputs
        The workflow's inputs, keyed by name. Each is one value - text, a
        number, or a bool; a list, a hashtable, or another object is
        refused, as the workflow would never see one. A name starts with
        a letter or _ and holds only letters, digits, _ and -, as GitHub
        requires. GitHub shows a dispatch's inputs in the run, so a secret
        does not belong in an input.
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
        System.Management.Automation.PSCustomObject
        One object per dispatch: Url, the new run's web address, and
        DatabaseId, its id - both $null when gh reported no run.
    .EXAMPLE
        Start-GitHubWorkflow -Workflow 'ci.yml' -Ref 'main' `
            -Repository 'OWNER/REPO'

        Dispatches ci.yml on main in OWNER/REPO.
    .EXAMPLE
        $inputs = @{ version = '1.2.3'; dry_run = $DryRun }
        $before = @(Get-GitHubWorkflowRun -List -Workflow 'release.yml' `
            -Trigger workflow_dispatch -Limit 1)
        $dispatch = Start-GitHubWorkflow -Workflow 'release.yml' -Ref 'main' `
            -Inputs $inputs
        $runId = $dispatch.DatabaseId
        if ($null -eq $runId) {
            $runId = Wait-GitHubWorkflowRunStart -Workflow 'release.yml' `
                -Before $before -Ref 'main'
        }
        $run = Wait-GitHubWorkflowRun -RunId $runId

        Dispatches release.yml on main, sending dry_run as true or false
        from a [switch], and waits for the run it started to finish -
        found by polling when gh did not report it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Wait-GitHubWorkflowRun
    .LINK
        Wait-GitHubWorkflowRunStart
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Workflow,

        [string]$Ref,

        [hashtable]$Inputs,

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
            if ($PSBoundParameters.ContainsKey('Ref') -and $Ref -notmatch '\S') {
                throw '-Ref is blank: give a branch or tag, or leave it out for the default branch.'
            }
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
            $fields = [ordered]@{}
            if ($Inputs) {
                foreach ($name in $Inputs.PSBase.Keys) {
                    if ("$name" -notmatch '^[A-Za-z_][A-Za-z0-9_-]*$') {
                        $shownName = Hide-UrlCredential -Text "$name"
                        throw "'$shownName' is not a workflow input name:" +
                        ' a name starts with a letter or _ and holds only letters, digits, _ and -.'
                    }

                    $value = $Inputs[$name]
                    if ($null -ne $value -and $value -isnot [string] -and $value -isnot [ValueType]) {
                        throw "Input '$name' holds [$($value.GetType().Name)], and a workflow input is one value:" +
                        ' give text, a number, or a bool.'
                    }

                    $fields["$name"] = if ($null -eq $value) {
                        ''
                    }
                    elseif ($value -is [bool] -or $value -is [switch]) {
                        ([bool]$value).ToString().ToLowerInvariant()
                    }
                    elseif ($value -is [datetime] -or $value -is [datetimeoffset]) {
                        $value.ToString('o')
                    }
                    else {
                        [string]$value
                    }
                }
            }

            $json = $null
            if ($fields.PSBase.Count -gt 0) {
                $sorted = [ordered]@{}
                foreach ($key in $fields.PSBase.Keys | Sort-Object) {
                    $sorted[$key] = $fields[$key]
                }

                $json = $sorted | ConvertTo-Json -Compress
            }

            $arguments = @('workflow', 'run')
            if ($Ref) {
                $arguments += "--ref=$Ref"
            }

            if ($json) {
                $arguments += '--json'
            }

            $arguments += @('--', $reference)
            $shownRef = Hide-UrlCredential -Text $Ref
            $action = if ($Ref) { "Dispatch workflow on $shownRef" } else { 'Dispatch workflow' }
            $target = Format-GitHubItemTarget -Repository $repositoryReference -Item "workflow $reference"
            if (-not $PSCmdlet.ShouldProcess($target, $action)) {
                return
            }

            $invocation = @{
                Activity   = "Dispatching workflow $reference"
                Arguments  = $arguments
                Repository = $repositoryReference
            }
            if ($json) {
                $invocation['StdIn'] = $json
            }

            $out = Invoke-GitHubCommand @invocation
            $url = @($out) -match '^https?://\S+$' | Select-Object -First 1
            $id = $null
            if ($url -match '/actions/runs/(\d+)') {
                $id = [long]$Matches[1]
            }

            return [PSCustomObject]@{
                Url        = $url
                DatabaseId = $id
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
