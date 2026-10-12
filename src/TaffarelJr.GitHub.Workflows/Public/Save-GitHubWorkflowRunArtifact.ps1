function Save-GitHubWorkflowRunArtifact {
    <#
    .SYNOPSIS
        Downloads and extracts the artifacts of a workflow run.
    .DESCRIPTION
        Each artifact extracts into its own folder under -Destination,
        named after it - except a single named artifact, which gh
        extracts straight into -Destination. Without -RunId, gh takes the
        most recent artifact of each given name across the repository's
        runs; since a later run can overwrite an artifact, name the run
        when it matters which one.

        With none of -RunId, -Name, and -Pattern, gh would download the
        latest of every artifact in the repository, so that call is
        refused; -Pattern '*' asks for exactly that, on purpose.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER RunId
        The run, by its database id. Omit it to search every run. A run
        piped in binds by its DatabaseId; a job, or any other object whose
        Url is not that run's, is refused.
    .PARAMETER Name
        Downloads only artifacts with one of these exact names. A blank
        name in the list is refused.
    .PARAMETER Pattern
        Downloads only artifacts whose name matches one of these globs. A
        blank pattern in the list is refused.
    .PARAMETER Destination
        The folder to extract into, written the PowerShell way: relative
        to the current location, ~ for the home folder, or on a drive
        such as Temp:. gh's default is the current location. A blank
        value is refused, and on Windows, which cannot handle a folder
        name that ends in white space, so is one that does.
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
        Save-GitHubWorkflowRunArtifact -RunId 123456789 -Name 'coverage' `
            -Destination './artifacts' -Repository 'OWNER/REPO'

        Downloads the coverage artifact of run 123456789 into ./artifacts.
    .EXAMPLE
        Save-GitHubWorkflowRunArtifact -Pattern 'test-*'

        Downloads the latest artifacts whose name starts with test-, in the
        current directory's repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Get-GitHubWorkflowRun
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('DatabaseId')]
        [ValidateRange(1, [long]::MaxValue)]
        [long]$RunId,

        [string[]]$Name,

        [string[]]$Pattern,

        [string]$Destination,

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
            $lists = [ordered]@{
                Name    = $Name
                Pattern = $Pattern
            }
            foreach ($list in $lists.GetEnumerator()) {
                $parameter = $list.Key
                $noun = $parameter.ToLowerInvariant()
                foreach ($value in $list.Value) {
                    if ("$value" -notmatch '\S') {
                        throw "-$parameter has a blank element, which gh would read as no $noun." +
                        " Give each one, or leave -$parameter out."
                    }
                }
            }

            if ($PSBoundParameters.ContainsKey('Destination')) {
                if ([string]::IsNullOrWhiteSpace($Destination)) {
                    throw '-Destination is blank: give a folder, or leave it out.'
                }

                if ($IsWindows -and $Destination -match '\s\z') {
                    $shownDestination = Hide-UrlCredential -Text $Destination
                    throw "-Destination '$shownDestination' ends in white space, which Windows cannot handle in" +
                    ' a folder name: give it without.'
                }
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
            $piped = if ($MyInvocation.ExpectingInput) { $_ } else { $null }
            $repositoryReference = Resolve-GitHubRunRepository -InputObject $piped -RunId $RunId `
                -Repository $Repository `
                -Advice 'Give the run it belongs to.'
            $hasRun = $PSBoundParameters.ContainsKey('RunId')
            if (-not $hasRun -and -not $Name -and -not $Pattern) {
                throw 'Give -RunId, -Name, or -Pattern: with none of them, gh would download the latest of' +
                " every artifact in the repository. To ask for exactly that, give -Pattern '*'."
            }

            $arguments = @('run', 'download')
            if ($hasRun) {
                $arguments += $RunId
            }

            foreach ($artifact in $Name) {
                $arguments += "--name=$artifact"
            }

            foreach ($glob in $Pattern) {
                $arguments += "--pattern=$glob"
            }

            if ($PSBoundParameters.ContainsKey('Destination')) {
                $folder = Resolve-GitHubPath -Path $Destination
                $arguments += @('--dir', $folder)
            }
            else {
                $folder = (Get-Location -PSProvider FileSystem).ProviderPath
            }

            if ($hasRun) {
                $source = Format-GitHubItemTarget -Repository $repositoryReference -Item "workflow run $RunId"
                $which = if ($Name -or $Pattern) { 'the matching artifacts' } else { 'the artifacts' }
            }
            else {
                $source = Format-GitHubItemTarget -Repository $repositoryReference
                $which = 'the latest matching artifacts'
            }

            $action = "Download $which of $source"
            $shownFolder = Hide-UrlCredential -Text $folder
            if (-not $PSCmdlet.ShouldProcess($shownFolder, $action)) {
                return
            }

            $activity = 'Downloading workflow run artifacts'
            Invoke-GitHubCommand -Activity $activity -Arguments $arguments -Repository $repositoryReference | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
