function Get-GitHubPullRequestCheck {
    <#
    .SYNOPSIS
        Returns the CI checks of a pull request, optionally waiting for
        them to finish first.
    .DESCRIPTION
        gh signals the overall outcome through its exit code - failing
        checks and still-pending checks are both non-zero - so this reads
        the result regardless of exit code and leaves the verdict to the
        caller, who has every check's State and Bucket to judge it by. A
        failure that produced no checks at all - no such pull request,
        no authentication - still throws.
    .PARAMETER PullRequest
        The pull request: its number, URL, or head branch. Omit it to use
        the current branch's pull request.
    .PARAMETER Required
        Returns only the checks the branch protection requires.
    .PARAMETER Watch
        Waits for every check to finish before returning.
    .PARAMETER FailFast
        With -Watch, stops waiting at the first failed check.
    .PARAMETER Interval
        With -Watch, how many seconds to wait between polls. gh's default
        is 10.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object per check - Name, State, Bucket (pass, fail, pending,
        skipping, or cancel), Workflow, Event, Description, Link,
        StartedAt, CompletedAt - always an array.
    #>
    param(
        [Parameter(Position = 0)]
        [string]$PullRequest,

        [switch]$Required,

        [switch]$Watch,

        [switch]$FailFast,

        [int]$Interval,

        [string]$Repository
    )

    $arguments = @('pr', 'checks')
    if ($PullRequest) {
        $arguments += $PullRequest
    }

    $arguments += @('--json', 'bucket,completedAt,description,event,link,name,startedAt,state,workflow')
    if ($Required) {
        $arguments += '--required'
    }

    if ($Watch) {
        $arguments += '--watch'
    }

    if ($FailFast) {
        $arguments += '--fail-fast'
    }

    if ($Interval -gt 0) {
        $arguments += @('--interval', $Interval)
    }

    $result = Invoke-GitHubCommand -Activity 'Reading pull request checks' -Arguments $arguments -Repository $Repository -Tolerant
    try {
        $checks = ConvertFrom-GitHubJson -Lines $result.Output
    }
    catch {
        $detail = ($result.Output | Out-String).Trim()
        throw "Reading pull request checks failed: gh $($arguments -join ' ') (exit $($result.ExitCode))`n$detail"
    }

    return , @($checks)
}
