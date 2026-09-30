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
Use-FakeOutputRedirect -Module $module -Redirected $true

# Act
$width = & $module { Get-HostWidth }

# Assert
Assert-Equal -Expected 0 -Actual $width -Message 'Redirected output reports no width, as a host with no window does'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - output going to the console
Use-FakeOutputRedirect -Module $module -Redirected $false
$hostReading = $Host.UI.RawUI.WindowSize.Width

# Act
$width = & $module { Get-HostWidth }

# Assert
Assert-Equal -Expected $hostReading -Actual $width -Message 'Console output reports exactly the width the host gives'

exit (Complete-TestRun)
