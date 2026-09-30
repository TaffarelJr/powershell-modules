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
$null = @(Get-HostOutput { Write-Step 'Build'; Write-Step 'Test' })

# Act
Clear-Step
$label = Get-CurrentStep

# Assert
Assert-Equal -Expected '' -Actual $label -Message 'Clear-Step empties the current step label'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
$null = @(Get-HostOutput { Write-Step 'Build'; Write-Step 'Test' })

# Act - the next run of steps starts over
Clear-Step
$null = @(Get-HostOutput { Write-Step 'Deploy' })
$label = Get-CurrentStep

# Assert
Assert-Equal -Expected 'Step 1: Deploy' -Actual $label `
    -Message 'Clear-Step restarts the numbering, so a later run does not continue from the last one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nothing to clear
Reset-ConsoleOutputState -Module $module

# Act
$printed = @(Get-HostOutput { Clear-Step })
$label = Get-CurrentStep

# Assert
Assert-Equal -Expected '' -Actual $label -Message 'Clearing when no step is active is a no-op, not an error'
Assert-Equal -Expected 0 -Actual $printed.Count -Message 'and prints nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a Doing line left open, as when the work it announced threw
Reset-ConsoleOutputState -Module $module
$expected = @('  ▶ deploy ...', '', "  $([char]0x2705) later run")

# Act
$messages = @(Get-HostOutput {
        Write-Doing 'deploy'
        Clear-Step
        Write-Done -Text 'later run'
    })
$stillOpen = & $module { $script:LineOpen }

# Assert
Assert-Equal -Expected $expected -Actual $messages `
    -Message 'Clear-Step ends an open line, so a later Write-Done prints its own line'
Assert-Equal -Expected $false -Actual $stillOpen -Message 'and nothing is left open'

exit (Complete-TestRun)
