#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

# A uniquely-named, disposable variable, process-scope only -
# no real persistent state to clean up here,
# unlike Set-EnvironmentVariable's tests.
$varName = "TAFFARELJR_USERINPUT_TEST_$([Guid]::NewGuid().ToString('N'))"

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an unset variable returns $null
Assert-Equal -Expected $null -Actual (Get-EnvironmentVariable -Name $varName) -Message 'An unset environment variable returns $null'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
[Environment]::SetEnvironmentVariable($varName, '  value  ')

# Act / Assert
Assert-Equal -Expected 'value' -Actual (Get-EnvironmentVariable -Name $varName) -Message 'A set value is trimmed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - whitespace-only counts as unset
[Environment]::SetEnvironmentVariable($varName, '   ')

# Act / Assert
Assert-Equal -Expected $null -Actual (Get-EnvironmentVariable -Name $varName) -Message 'A whitespace-only value is treated the same as unset'

# Cleanup
[Environment]::SetEnvironmentVariable($varName, $null)

exit (Complete-TestRun)
