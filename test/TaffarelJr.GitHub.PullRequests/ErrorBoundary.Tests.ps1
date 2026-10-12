#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') `
    -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$category = [System.Management.Automation.ErrorCategory]
$null = Use-FakePollClock -Module $module

# A plain throw is skipped under -ErrorAction SilentlyContinue, and the function carries on to its change,
# but only where no try block encloses the call. So each case runs as a script of its own in a runspace of
# its own, with the modules imported once.
$shell = [powershell]::Create()
$import = {
    param($Root)

    foreach ($name in 'TaffarelJr.ProcessInvocation', 'TaffarelJr.GitHub.Core', 'TaffarelJr.GitHub.PullRequests') {
        Import-Module (Join-Path $Root "src/$name/$name.psd1") -Force
    }
}
$run = {
    param([string]$Script)

    $shell.Commands.Clear()
    $shell.Streams.ClearStreams()
    $null = $shell.AddScript($Script)
    [PSCustomObject]@{
        Output = @($shell.Invoke())
        Errors = @($shell.Streams.Error)
    }
}

$fake = New-FakeGitHubCli
try {
    $null = $shell.AddScript($import.ToString()).AddArgument($repoRoot).Invoke()

    #───────────────────────────────────────────────────────────────────────────────
    # Arrange - a failure in each kind of block, and the record it raises
    $cases = @(
        @{
            Block   = 'begin block'
            Command = 'Close-GitHubPullRequest'
            Call    = "Close-GitHubPullRequest -PullRequest 12 -Comment ' '"
            Id      = 'RuntimeException,Close-GitHubPullRequest'
            Message = '-Comment is blank: give the comment''s text, or leave it out.'
        }
        @{
            Block   = 'process block'
            Command = 'Lock-GitHubPullRequest'
            Call    = "Lock-GitHubPullRequest -PullRequest 'feature/x'"
            Id      = 'RuntimeException,Lock-GitHubPullRequest'
            Message = '''feature/x'' is not a pull request: give its number or URL, as gh takes no branch name here.'
        }
        @{
            Block   = 'only block'
            Command = 'New-GitHubPullRequest'
            Call    = "New-GitHubPullRequest -Title ' ' -Body 'b' -Repository 'o/r'"
            Id      = 'RuntimeException,New-GitHubPullRequest'
            Message = '-Title is blank: give a title, or leave it out.'
        }
    )
    foreach ($case in $cases) {
        foreach ($preference in 'SilentlyContinue', 'Ignore') {
            # Act
            $result = & $run "$($case.Call) -ErrorAction $preference"
            $calls = @(Get-FakeGitHubCall -Fixture $fake)
            $raised = $result.Errors | Select-Object -First 1

            # Assert
            Assert-Equal -Expected 0 -Actual $calls.Count `
                -Message "A failure in $($case.Command)'s $($case.Block) does not carry on to gh under $preference"
            Assert-Equal -Expected @() -Actual $result.Output -Message 'and returns nothing'
            Assert-Equal -Expected 1 -Actual $result.Errors.Count -Message 'but raises one error'
            Assert-Equal -Expected $case.Id -Actual $raised.FullyQualifiedErrorId `
                -Message 'whose ID is the exception type and the command'
            Assert-Equal -Expected $category::InvalidOperation -Actual $raised.CategoryInfo.Category `
                -Message 'whose category is an invalid operation'
            Assert-Equal -Expected $case.Message -Actual $raised.TargetObject `
                -Message 'and whose target is the message thrown'
        }

        # Act
        $result = & $run "try { $($case.Call) -ErrorAction Stop } catch { `$_ }"
        $calls = @(Get-FakeGitHubCall -Fixture $fake)
        $raised = $result.Output | Select-Object -First 1

        # Assert
        Assert-Equal -Expected 0 -Actual $calls.Count -Message 'Under -ErrorAction Stop it stops too, before gh'
        Assert-Equal -Expected $case.Id -Actual $raised.FullyQualifiedErrorId `
            -Message 'with the same ID'
        Assert-Equal -Expected $case.Message -Actual $raised.Exception.Message `
            -Message 'and the message thrown'
    }

    #───────────────────────────────────────────────────────────────────────────────
    # Arrange - a pipeline of three pull requests, the second in another repository than -Repository
    $pipeline = "'1', 'https://github.com/a/b/pull/2', '3' | Close-GitHubPullRequest -Repository 'c/d'"

    # Act
    $result = & $run "$pipeline -ErrorAction SilentlyContinue"
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count `
        -Message 'A failing record stops the pipeline: only the first is closed'
    Assert-Equal -Expected @('pr', 'close', '1', '--repo', 'c/d') -Actual $calls[0].Arguments `
        -Message 'and it is the one before the failure'
    Assert-Equal -Expected 1 -Actual $result.Errors.Count -Message 'with one error raised'

    #───────────────────────────────────────────────────────────────────────────────
    # Arrange - a wait that runs out of time
    $pending = '[{"name":"deploy","state":"PENDING","bucket":"pending"}]'
    $waitFake = New-FakeGitHubCli -Output @($pending)
    try {
        # Act
        $record = $null
        try {
            Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1 -TimeoutSeconds 3
        }
        catch {
            $record = $_
        }

        # Assert
        Assert-Equal -Expected 'TimeoutException,Get-GitHubPullRequestCheck' -Actual $record.FullyQualifiedErrorId `
            -Message 'A wait that times out is named by the exception type and the command'
        Assert-Equal -Expected $category::OperationTimeout -Actual $record.CategoryInfo.Category `
            -Message 'and is an operation that timed out'
        Assert-That -Condition ($record.Exception -is [System.TimeoutException]) `
            -Message 'with the TimeoutException itself'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $waitFake
    }
}
finally {
    $shell.Dispose()
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
