#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange - output going to a file or a pipe, from a host that may have a window
Use-FakeOutputRedirect -Module $module -Redirected $true

# Act
$redirected = & $module { Get-ConsoleWidth }

# Assert
Assert-Equal -Expected 80 -Actual $redirected `
    -Message 'Redirected output gets the default of 80, not the width of whatever window ran it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Use-FakeHostWidth -Module $module -Width 120

# Act
$wide = & $module { Get-ConsoleWidth }

# Assert
Assert-Equal -Expected 120 -Actual $wide -Message 'A host that reports a width has that width used'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Use-FakeHostWidth -Module $module -Width 0

# Act
$zero = & $module { Get-ConsoleWidth }

# Assert
Assert-Equal -Expected 80 -Actual $zero -Message 'A host that reports no width gets the default of 80'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Use-FakeHostWidth -Module $module -Throw

# Act
$none = & $module { Get-ConsoleWidth }

# Assert
Assert-Equal -Expected 80 -Actual $none -Message 'A host with no window at all, which throws, gets the default of 80'

exit (Complete-TestRun)
