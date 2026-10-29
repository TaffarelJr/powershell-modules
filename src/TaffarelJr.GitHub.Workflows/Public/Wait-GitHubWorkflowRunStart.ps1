using namespace System.Collections
using namespace System.Globalization

function Wait-GitHubWorkflowRunStart {
    <#
    .SYNOPSIS
        Waits for a run dispatched by Start-GitHubWorkflow to appear, and
        returns its id.
    .DESCRIPTION
        The fallback for a dispatch whose run Start-GitHubWorkflow could
        not report - an older gh, or a GitHub that does not return it.
        The run does not exist the instant the dispatch returns, so this
        polls gh for the workflow's workflow_dispatch runs (on -Ref's
        branch, when given) until one newer than every run in -Before
        shows up, and returns the newest such run. Run ids only grow, so
        it does not matter how many runs -Before holds: a listing of the
        latest one is enough, as long as that listing is at least as
        broad as this poll - list -Before with -Trigger workflow_dispatch
        and the same -Ref as -Branch (or neither), as the example does.
        A narrower listing leaves out older runs this poll then takes for
        new. A run dispatched by someone else at the same moment is
        indistinguishable, so prefer the DatabaseId Start-GitHubWorkflow
        returns when it has one.

        The poll runs where the dispatch went: a workflow object is read
        for its Repository, as Start-GitHubWorkflow reads it, and so is
        each run in -Before; a -Repository, or a -Before run, naming
        another repository throws.

        The timeout is measured on a monotonic clock, the last sleep ends
        at the deadline, and the runs are listed once more there. A poll
        whose gh read fails ends the wait at once, whatever the failure -
        no workflow by that name, a 403, a rate limit, a server error, no
        network - with gh's message, which names the HTTP status when there
        is one, so 'the run never started' is never mistaken for 'gh could
        not be reached'. -TimeoutSeconds bounds the wait only while the
        reads succeed. Each poll is one gh call with no time limit of its
        own, so a gh that stalls on the network stalls the wait.
    .PARAMETER Workflow
        The workflow, by id, name, or file name such as 'ci.yml', or a
        workflow object from Get-GitHubWorkflow, read by its Id and acted
        on in its Repository.
    .PARAMETER Before
        The workflow's runs immediately before dispatching - the objects
        Get-GitHubWorkflowRun -List returned, or their DatabaseId values.
        Read them before calling Start-GitHubWorkflow, or the new run is
        among them, and with -Trigger workflow_dispatch and the same ref.
        Empty or $null when the workflow had no runs, in which case any
        run counts as new.
    .PARAMETER Ref
        The branch or tag the workflow was dispatched on, to look only at
        runs of that ref. A blank value is refused.
    .PARAMETER TimeoutSeconds
        How many seconds to wait in all for the run to appear, 1 to 86400.
        The default is 300, shorter than a run's wait, because a
        dispatched run normally appears within seconds. The runs are
        listed once more at the deadline, and no new run then throws a
        TimeoutException.
    .PARAMETER PollSeconds
        How many seconds to wait between polls, 1 to 3600. The default is
        5; the last pause is cut short at the deadline.
    .PARAMETER Repository
        The repository, as [HOST/]OWNER/REPO, a URL, or a repository
        object. Omit it to use the repository of the workflow object or
        the -Before runs, else the current directory's; a -Repository
        given as $null throws.
    .INPUTS
        None
    .OUTPUTS
        System.Int64
        The new run's database id. No new run within the timeout throws a
        TimeoutException.
    .EXAMPLE
        $before = @(Get-GitHubWorkflowRun -List -Workflow 'ci.yml' `
            -Trigger workflow_dispatch -Branch 'main' -Limit 1)
        $dispatch = Start-GitHubWorkflow -Workflow 'ci.yml' -Ref 'main'
        $runId = $dispatch.DatabaseId
        if ($null -eq $runId) {
            $runId = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' `
                -Before $before -Ref 'main'
        }

        Finds the dispatched run's id, from the dispatch itself where gh
        reported it and by polling where it did not.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Start-GitHubWorkflow
    .LINK
        Wait-GitHubWorkflowRun
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [object]$Workflow,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Before,

        [string]$Ref,

        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds = 300,

        [ValidateRange(1, 3600)]
        [int]$PollSeconds = 5,

        [object]$Repository
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        Assert-GitHubFilterNotBlank -BoundParameters $PSBoundParameters -Name 'Ref'
        Resolve-GitHubRepositoryArgument -Value $Repository -Given $PSBoundParameters.ContainsKey('Repository') |
            Out-Null
        $reference = ConvertTo-GitHubWorkflowReference -Workflow $Workflow -NotPiped
        $repositoryReference = Resolve-GitHubOriginRepository -Repository $Repository -InputObject $Workflow `
            -Item "Workflow $reference"
        $shownReference = Hide-UrlCredential -Text $reference
        $anchor = $null
        if ($PSBoundParameters.ContainsKey('Repository')) {
            $anchor = '-Repository'
        }
        elseif ($repositoryReference) {
            $anchor = "workflow $shownReference"
        }

        $latest = [long]0
        foreach ($run in @($Before)) {
            if ($null -eq $run) {
                continue
            }

            $scalar = $run -is [string] -or $run -is [ValueType]
            $id = "$run"
            $url = ''
            if ($run -is [IDictionary]) {
                $id = ''
                foreach ($key in $run.PSBase.Keys) {
                    if ("$key" -eq 'DatabaseId') {
                        $id = "$($run[$key])"
                    }
                }
            }
            elseif (-not $scalar) {
                $id = "$($run.PSObject.Properties['DatabaseId']?.Value)"
                $url = "$($run.PSObject.Properties['Url']?.Value)"
            }

            $id = $id.Trim()
            if (-not $scalar -and -not $id) {
                throw "A run in -Before needs a DatabaseId, and this one has none: $($run.GetType().Name)."
            }

            $value = [long]0
            $parsed = [long]::TryParse($id, [NumberStyles]::None, [CultureInfo]::InvariantCulture, [ref]$value)
            if (-not $parsed -or $value -lt 1) {
                $shownId = Hide-UrlCredential -Text $id
                throw "'$shownId' in -Before is not a run id:" +
                ' give the runs Get-GitHubWorkflowRun -List returned, or their DatabaseId.'
            }

            $origin = $null
            if (-not $scalar) {
                $origin = Resolve-GitHubOriginRepository -InputObject $run -Url $url -Item "Run $value in -Before"
            }

            if ($origin -and -not $repositoryReference) {
                $repositoryReference = $origin
                $anchor = "run $value in -Before"
            }
            elseif ($origin -and $anchor -eq '-Repository') {
                $repositoryReference = Assert-GitHubSameRepository -Item "Run $value in -Before" -Origin $origin `
                    -Repository $repositoryReference `
                    -PassThru
            }
            elseif ($origin) {
                try {
                    $repositoryReference = Assert-GitHubSameRepository -Item "Run $value" -Origin $origin `
                        -Repository $repositoryReference `
                        -PassThru
                }
                catch {
                    $shown = foreach ($text in $origin, $repositoryReference) {
                        Format-GitHubRepositoryName -Repository $text
                    }
                    $advice = if ($anchor -like 'workflow *') { "the workflow's repository" } else { 'one repository' }
                    throw "Run $value in -Before is in $($shown[0]), but $anchor is in $($shown[1]):" +
                    " list -Before from $advice."
                }
            }

            $latest = [Math]::Max($latest, $value)
        }

        $arguments = @('run', 'list', '--workflow', $reference, '--event', 'workflow_dispatch')
        if ($Ref) {
            $arguments += "--branch=$Ref"
        }

        $arguments += @('--limit', '20', '--json', 'databaseId')
        $activity = "Listing the workflow_dispatch runs of '$reference'"
        $action = "list the workflow_dispatch runs of '$reference'"
        $poll = New-GitHubPoll -TimeoutSeconds $TimeoutSeconds -PollSeconds $PollSeconds
        while ($true) {
            $result = Invoke-GitHubCommand -Activity $activity -Arguments $arguments `
                -Repository $repositoryReference `
                -Tolerant
            Assert-GitHubPollRead -Result $result -Action $action
            $newest = $latest
            foreach ($run in @(ConvertFrom-GitHubJson -Lines $result.Output)) {
                $listed = $null
                if ($null -ne $run) {
                    $listed = $run.PSObject.Properties['DatabaseId']?.Value
                }

                if ($null -ne $listed) {
                    $newest = [Math]::Max($newest, [long]$listed)
                }
            }

            if ($newest -gt $latest) {
                return $newest
            }

            if (Test-GitHubPollExpired -Poll $poll) {
                $subject = "No new workflow_dispatch run of '$reference' appeared within $TimeoutSeconds s."
                $message = Get-GitHubTimeoutMessage -Subject $subject
                throw [TimeoutException]::new($message)
            }

            Wait-GitHubPoll -Poll $poll | Out-Null
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
