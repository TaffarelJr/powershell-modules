#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Test-FileFailed.ps1')

# Arrange / Act / Assert - a clean pass is not a failure
$clean = [pscustomobject]@{ ExitCode = 0; Crashed = $false }
Assert-That -Condition (-not (Test-FileFailed -Result $clean)) -Message 'Exit 0, not crashed, is not a failure'

# Arrange / Act / Assert - a non-zero exit is a failure
$failed = [pscustomobject]@{ ExitCode = 1; Crashed = $false }
Assert-That -Condition (Test-FileFailed -Result $failed) -Message 'A non-zero exit counts as a failure'

# Arrange / Act / Assert - a crash at exit 0 is still a failure
$crashedAtZero = [pscustomobject]@{ ExitCode = 0; Crashed = $true }
Assert-That -Condition (Test-FileFailed -Result $crashedAtZero) -Message 'A crash counts as a failure even at exit 0'

exit (Complete-TestRun)
