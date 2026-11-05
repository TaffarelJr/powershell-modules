#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')

# Reading a key needs a console, and a test cannot supply one - from here it
# would either wait for a person or fail. A child process whose input is closed
# shows the failure Wait-KeyPress has to be ready for, which is also why the
# call itself is not in the coverage report.

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a process whose input is redirected
$script = "& (Get-Module TaffarelJr.UserInput) { try { Read-KeyPress; 'read a key' } catch { 'threw ' + `$_.Exception.GetBaseException().GetType().Name } }"
$child = Invoke-ChildPowerShell -Script $script

# Assert
Assert-That -Condition (-not $child.TimedOut) -Message 'Reading a key from closed input does not wait for one'
Assert-Equal -Expected 'threw InvalidOperationException' -Actual $child.Output.Trim() `
    -Message 'It fails with an InvalidOperationException, the failure Wait-KeyPress must handle'

exit (Complete-TestRun)
