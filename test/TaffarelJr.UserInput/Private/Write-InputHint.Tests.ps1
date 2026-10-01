#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
$module = Get-Module TaffarelJr.UserInput

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { & $module { Write-InputHint -Hint @('first', 'second') } })

# Assert
Assert-Equal -Expected @('     first', '     second') -Actual $lines -Message 'Each hint is a detail line, in order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$none = @(Get-HostOutput { & $module { Write-InputHint } })
$empty = @(Get-HostOutput { & $module { Write-InputHint -Hint @() } })

# Assert
Assert-Equal -Expected 0 -Actual $none.Count -Message 'No hint prints nothing'
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'and neither does an empty list of them'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a blank hint line
$blank = @(Get-HostOutput { & $module { Write-InputHint -Hint @('') } })

# Assert
Assert-Equal -Expected @('     (no message)') -Actual $blank `
    -Message 'A blank hint is shown as the placeholder every line of this module gets, never as nothing'

exit (Complete-TestRun)
