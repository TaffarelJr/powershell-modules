#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/New-TestFileResult.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - only the name given
$bare = New-TestFileResult -Name 'Some'

# Assert
Assert-Equal -Expected 'Some' -Actual $bare.Name -Message 'Carries the name'
Assert-Equal -Expected 0 -Actual $bare.Passed -Message 'Passed defaults to zero'
Assert-Equal -Expected 0 -Actual $bare.Failed -Message 'Failed defaults to zero'
Assert-Equal -Expected $false -Actual $bare.Crashed -Message 'A result is not crashed unless said to be'
Assert-Equal -Expected $false -Actual $bare.TimedOut -Message 'A result is not timed out unless said to be'
Assert-Equal -Expected $false -Actual $bare.NotStarted -Message 'A result is started unless said not to be'
Assert-Equal -Expected $false -Actual $bare.Skipped -Message 'A result is not skipped unless said to be'
Assert-Equal -Expected '' -Actual $bare.SkipReason -Message 'and has no skip reason'
Assert-Equal -Expected $false -Actual $bare.AllowedEmpty -Message 'A result is not allowed empty unless said to be'
Assert-Equal -Expected 0 -Actual $bare.ExitCode -Message 'The exit code defaults to zero'
Assert-Equal -Expected 0 -Actual $bare.Seconds -Message 'The time defaults to zero'
Assert-Equal -Expected 0 -Actual @($bare.Output).Count -Message 'The output defaults to nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - everything given
$full = New-TestFileResult -Name 'Some' -Passed 3 -Failed 2 -Crashed -TimedOut -NotStarted -Skipped -SkipReason 'why' `
    -AllowedEmpty `
    -ExitCode 124 `
    -Seconds 1.5 `
    -Output 'one', 'two'

# Assert
Assert-Equal -Expected 3 -Actual $full.Passed -Message 'Carries the passed count'
Assert-Equal -Expected 2 -Actual $full.Failed -Message 'Carries the failed count'
Assert-Equal -Expected $true -Actual $full.Crashed -Message 'Carries -Crashed as a boolean'
Assert-Equal -Expected $true -Actual $full.TimedOut -Message 'Carries -TimedOut as a boolean'
Assert-Equal -Expected $true -Actual $full.NotStarted -Message 'Carries -NotStarted as a boolean'
Assert-Equal -Expected $true -Actual $full.Skipped -Message 'Carries -Skipped as a boolean'
Assert-Equal -Expected 'why' -Actual $full.SkipReason -Message 'Carries the skip reason'
Assert-Equal -Expected $true -Actual $full.AllowedEmpty -Message 'Carries -AllowedEmpty as a boolean'
Assert-Equal -Expected 124 -Actual $full.ExitCode -Message 'Carries the exit code'
Assert-Equal -Expected 1.5 -Actual $full.Seconds -Message 'Carries the time'
Assert-Equal -Expected 'one|two' -Actual ($full.Output -join '|') -Message 'Carries the output, a line at a time'

#───────────────────────────────────────────────────────────────────────────────
# Act - the switches given as values, the way a caller passes a computed one
$off = New-TestFileResult -Name 'Some' -Crashed:$false -TimedOut:$false

# Assert
Assert-Equal -Expected $false -Actual $off.Crashed -Message '-Crashed:$false is not crashed'
Assert-Equal -Expected $false -Actual $off.TimedOut -Message '-TimedOut:$false is not timed out'

exit (Complete-TestRun)
