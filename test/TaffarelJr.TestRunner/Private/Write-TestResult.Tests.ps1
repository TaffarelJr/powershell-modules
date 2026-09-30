#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Format-TestVerdict.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Write-TestResult.ps1')

# Arrange - a passing result
$passResult = [pscustomobject]@{ Crashed = $false; ExitCode = 0; Passed = 4; Failed = 0; Seconds = 1.234; Output = @('line one', 'line two') }

# Act
$lines = Get-HostOutput { Write-TestResult -Result $passResult }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'A passing result prints only the verdict line, not its output'
Assert-That -Condition ($lines[0] -like '*4 passed*1.2s*') -Message 'The verdict line names the pass count and the elapsed seconds'

# Arrange - a failing result
$failResult = [pscustomobject]@{ Crashed = $false; ExitCode = 1; Passed = 2; Failed = 1; Seconds = 0.5; Output = @('the actual error') }

# Act
$failLines = Get-HostOutput { Write-TestResult -Result $failResult }

# Assert
Assert-Equal -Expected 2 -Actual $failLines.Count -Message 'A failing result also prints its captured output'
Assert-That -Condition ($failLines[1] -like '*the actual error*') -Message 'The failing output is printed after the verdict'

# Arrange / Act - a passing result, but the caller asked to see output anyway
$shownLines = Get-HostOutput { Write-TestResult -Result $passResult -ShowOutput }

# Assert
Assert-Equal -Expected 3 -Actual $shownLines.Count -Message '-ShowOutput prints a passing result''s output too'

exit (Complete-TestRun)
