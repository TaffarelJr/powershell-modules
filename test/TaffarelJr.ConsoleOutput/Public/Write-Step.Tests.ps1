#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 30

# Act - a step is rendered as a header: blank, rule, text, rule, blank
$lines = @(Get-HostOutput { Write-Step 'Build' })

# Assert
Assert-Equal -Expected @('', ('─' * 28), 'Step 1: Build'.PadRight(28), ('─' * 28), '') -Actual $lines `
    -Message 'Write-Step renders its numbered title as a header'
Assert-Equal -Expected 'Step 1: Build' -Actual (Get-CurrentStep) -Message 'and records it as the current step'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 30

# Act - the number auto-increments; the caller never tracks it
$null = @(Get-HostOutput { Write-Step 'Build' })
$second = @(Get-HostOutput { Write-Step 'Test' })

# Assert
Assert-Equal -Expected 'Step 2: Test'.PadRight(28) -Actual $second[2] -Message 'A second call auto-increments to step 2'
Assert-Equal -Expected 'Step 2: Test' -Actual (Get-CurrentStep) `
    -Message 'and replaces the current step rather than nesting'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 30

# Act - pipeline input
$piped = @(Get-HostOutput { 'A', 'B' | Write-Step })

# Assert
Assert-Equal -Expected 10 -Actual $piped.Count -Message 'Piping two titles renders two separate five-line headers'
Assert-Equal -Expected 'Step 1: A'.PadRight(28) -Actual $piped[2] -Message 'The first piped title is step 1'
Assert-Equal -Expected 'Step 2: B'.PadRight(28) -Actual $piped[7] -Message 'The second is step 2'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 30

# Act - empty text is allowed, like every other writer
$null = @(Get-HostOutput { Write-Step '' })

# Assert
Assert-Equal -Expected 'Step 1: (no message)' -Actual (Get-CurrentStep) `
    -Message 'Empty text renders the placeholder instead of throwing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 30

# Act - a Doing line left open by the step before
$lines = @(Get-HostOutput { Write-Doing 'deploy'; Write-Step 'Next' })
$stillOpen = & $module { $script:LineOpen }

# Assert
Assert-Equal -Expected @('  ▶ deploy ...', '', '', ('─' * 28), 'Step 1: Next'.PadRight(28), ('─' * 28), '') `
    -Actual $lines `
    -Message 'A new step ends an open line before its header'
Assert-Equal -Expected $false -Actual $stillOpen -Message 'and leaves nothing open'

exit (Complete-TestRun)
