#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Format-TestVerdict.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a clean pass
$passed = Format-TestVerdict -Result ([PSCustomObject]@{ Crashed = $false; ExitCode = 0; Passed = 5; Failed = 0 })

# Assert
Assert-That -Condition ($passed -like '*5 passed*') -Message 'A clean run reports the passed count'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - real failures
$failed = Format-TestVerdict -Result ([PSCustomObject]@{ Crashed = $false; ExitCode = 1; Passed = 3; Failed = 2 })

# Assert
Assert-That -Condition ($failed -like '*3 passed*2 failed*') -Message 'A failing run reports both counts'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a crash takes priority over whatever counts happened to be captured
$crashed = Format-TestVerdict -Result ([PSCustomObject]@{ Crashed = $true; ExitCode = 134; Passed = 0; Failed = 0 })

# Assert
Assert-That -Condition ($crashed -like '*crashed*134*') -Message 'A crash reports as crashed, naming the exit code'

exit (Complete-TestRun)
