#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
# A poll whose clock reads a fixed elapsed time and whose sleep only records.
$slept = [System.Collections.Generic.List[int]]::new()
$newPoll = {
    param([double]$ElapsedSeconds)
    $poll = New-GitHubPoll -TimeoutSeconds 60 -PollSeconds 5
    $poll.Clock = [PSCustomObject]@{ Elapsed = [TimeSpan]::FromSeconds($ElapsedSeconds) }
    $poll.Sleep = { param($Milliseconds) $slept.Add($Milliseconds) }
    $poll
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$slept.Clear()
$fresh = & $newPoll 0
$nearEnd = & $newPoll 58.5
$lastMillisecond = & $newPoll 59.9995

# Act
$pauses = @(
    Wait-GitHubPoll -Poll $fresh
    Wait-GitHubPoll -Poll $nearEnd
    Wait-GitHubPoll -Poll $lastMillisecond
)

# Assert
Assert-Equal -Expected @(5000, 1500, 1) -Actual $pauses `
    -Message 'The pause is the interval, never past the time left, rounded up to a whole millisecond'
Assert-Equal -Expected @(5000, 1500, 1) -Actual @($slept) -Message 'and that is what is slept'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$slept.Clear()
$over = & $newPoll 61

# Act
$pause = Wait-GitHubPoll -Poll $over

# Assert
Assert-Equal -Expected 0 -Actual $pause -Message 'A deadline already passed gives no pause'
Assert-Equal -Expected 0 -Actual $slept.Count -Message 'and nothing sleeps'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the real sleep, with almost no time left
$poll = New-GitHubPoll -TimeoutSeconds 1 -PollSeconds 1
$poll.Clock = [PSCustomObject]@{ Elapsed = [TimeSpan]::FromMilliseconds(990) }
$clock = [System.Diagnostics.Stopwatch]::StartNew()

# Act
$pause = Wait-GitHubPoll -Poll $poll

# Assert
Assert-Equal -Expected 10 -Actual $pause -Message 'The default Sleep really sleeps the clamped pause'
Assert-That -Condition ($clock.ElapsedMilliseconds -ge 9) -Message "for that long ($($clock.ElapsedMilliseconds) ms)"

exit (Complete-TestRun)
