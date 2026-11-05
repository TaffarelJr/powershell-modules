function Get-GitHubPullRequestCheck {
    <#
    .SYNOPSIS
        Returns the CI checks of a pull request, optionally waiting for
        them to finish first.
    .DESCRIPTION
        gh prints the checks with exit 0 whatever their state, so failing
        and pending checks are returned like passing ones and the verdict
        is the caller's, from each check's State and Bucket. A pull
        request with no checks - or, with -Required, no required ones -
        returns nothing. Any other non-zero exit means no checks were
        read - no such pull request, no authentication, no network - and
        throws, with gh's message. Needs gh 2.50 or later.

        -Wait reads the checks again every -PollSeconds until none is
        pending, then returns them. No checks reported yet counts as
        pending, since GitHub registers checks a few seconds after a push,
        and so does a check gh lists with a missing or blank bucket; an
        empty (null) entry in gh's list is skipped.
        Any other failed read ends the wait at once, whatever the failure -
        no such pull request, a 403, a rate limit, a server error, no
        network - with gh's message, which names the HTTP status when there
        is one, so -TimeoutSeconds bounds the wait only while the reads
        succeed. The last read comes at the deadline itself, and when
        checks are still pending then, it throws a TimeoutException naming
        them. A pull request
        that never reports checks - no CI, or -Required with none
        required - waits until -TimeoutSeconds and then throws: bound it
        with -TimeoutSeconds, or read without -Wait. gh's own --watch
        cannot be used here, as gh refuses it along with --json.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch, or a pull
        request object. Leave it out to use the current branch's pull
        request, which works only without -Repository: gh needs the pull
        request named along with it. Given as $null, it throws.
    .PARAMETER Required
        Returns only the checks the branch protection requires.
    .PARAMETER Wait
        Waits until no check is pending before returning. A pull request
        that never reports checks (no CI, or -Required with none required)
        waits until -TimeoutSeconds and then throws; bound it with
        -TimeoutSeconds, or read without -Wait.
    .PARAMETER PollSeconds
        With -Wait, how many seconds to wait between reads, 1 to 3600;
        5 when left out. No sleep runs past the deadline.
    .PARAMETER TimeoutSeconds
        With -Wait, how many seconds to wait for each pull request piped
        in (or the one named), 1 to 86400; 1800 when left out. The checks
        are read once more at the deadline, and if any is still pending
        then - or none was reported - it throws a TimeoutException naming
        what is pending.
    .PARAMETER FailFast
        With -Wait, stops waiting at the first failed check and returns
        the checks as they stand.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form or as a URL, or
        a repository object. Omit it to use the current directory's
        repository; given as $null, it throws. A pull request given by URL
        or object is in the repository it names; one in a different
        repository than this throws.
    .INPUTS
        System.Object
        A pull request: its number, URL, or head branch, or a pull request
        object such as Get-GitHubPullRequest returns. Binds to -PullRequest.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per check - Name, State, Bucket (pass, fail, pending,
        skipping, or cancel), Workflow, Event, Description, Link,
        StartedAt, CompletedAt.
    .EXAMPLE
        $checks = @(Get-GitHubPullRequestCheck -PullRequest 42 -Wait `
            -FailFast -TimeoutSeconds 900)
        $failed = @($checks | Where-Object Bucket -EQ 'fail')

        Waits up to 15 minutes for pull request 42's checks, stopping
        early at the first failure, then picks out the failed ones.
    .EXAMPLE
        Get-GitHubPullRequestCheck -PullRequest 42 -Required `
            -Repository 'OWNER/REPO'

        Returns the checks branch protection requires on pull request 42,
        without waiting for them.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/README.md
    .LINK
        Get-GitHubPullRequest
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$PullRequest,

        [switch]$Required,

        [switch]$Wait,

        [ValidateRange(1, 3600)]
        [int]$PollSeconds = 5,

        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds = 1800,

        [switch]$FailFast,

        [object]$Repository
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            if (-not $Wait) {
                foreach ($name in 'PollSeconds', 'TimeoutSeconds', 'FailFast') {
                    if ($PSBoundParameters.ContainsKey($name)) {
                        throw '-PollSeconds, -TimeoutSeconds, and -FailFast work only with -Wait: they shape' +
                        ' the wait. Give -Wait too, or leave them off.'
                    }
                }
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $noChecks = 'no (required )?checks reported'
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $resolve = @{
                BoundParameters = $PSBoundParameters
                Repository      = $repositoryReference
            }
            $target = Resolve-GitHubPullRequestTarget @resolve
            $fields = 'bucket,completedAt,description,event,link,name,startedAt,state,workflow'
            $arguments = @('pr', 'checks') + $target.Arguments + @('--json', $fields)
            if ($Required) {
                $arguments += '--required'
            }

            $command = @{
                Activity   = "Reading the checks of $($target.Name)"
                Arguments  = $arguments
                Repository = $repositoryReference
            }
            if (-not $Wait) {
                try {
                    $out = Invoke-GitHubCommand @command
                }
                catch {
                    # Only gh's own text, after the first line break, is matched:
                    # the line before it holds the arguments, a branch name included.
                    $parts = $_.Exception.Message -split "`n", 2
                    if ($parts.Count -eq 2 -and $parts[1] -match $noChecks) {
                        return
                    }

                    throw
                }

                if (-not $out) {
                    return
                }

                return ConvertFrom-GitHubJson -Lines $out
            }

            $poll = New-GitHubPoll -TimeoutSeconds $TimeoutSeconds -PollSeconds $PollSeconds
            while ($true) {
                $result = Invoke-GitHubCommand @command -Tolerant
                $answer = $result
                if (-not $result.Ok -and $result.Message -match $noChecks) {
                    $answer = @{ Ok = $true }
                }

                Assert-GitHubPollRead -Result $answer -Action "read the checks of $($target.Name)"
                $checks = @()
                if ($result.Ok -and $result.Output) {
                    $parsed = @(ConvertFrom-GitHubJson -Lines $result.Output)
                    $checks = @($parsed | Where-Object { $null -ne $_ })
                }

                $pending = @($checks | Where-Object {
                        $bucket = "$($_.PSObject.Properties['Bucket']?.Value)"
                        [string]::IsNullOrWhiteSpace($bucket) -or $bucket -eq 'pending'
                    })
                $failed = @($checks | Where-Object { $_.PSObject.Properties['Bucket']?.Value -eq 'fail' })
                $done = $checks.Count -gt 0 -and $pending.Count -eq 0
                if ($done -or ($FailFast -and $failed.Count -gt 0)) {
                    return $checks
                }

                if (Test-GitHubPollExpired -Poll $poll) {
                    $subject = "No checks of $($target.Name) were reported within $TimeoutSeconds s."
                    $names = @()
                    if ($pending.Count -gt 0) {
                        $names = @(foreach ($check in $pending) {
                                $name = $check.PSObject.Properties['Name']?.Value
                                if ($name) {
                                    $name
                                }
                                else {
                                    '(no name)'
                                }
                            })
                        $subject = "The checks of $($target.Name) were still pending after $TimeoutSeconds s:"
                    }

                    $message = Get-GitHubTimeoutMessage -Subject $subject -Detail $names
                    throw [System.TimeoutException]::new($message)
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
}
