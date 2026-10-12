#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-VSCodeArgument.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act
$arguments = Get-VSCodeArgument -Path 'one'

# Assert
Assert-That -Condition ($arguments -is [array]) -Message 'A single path still comes back as an array'
Assert-Equal -Expected @('one') -Actual $arguments -Message 'Without -Window, the path is the only argument'

#───────────────────────────────────────────────────────────────────────────────
# Act
$arguments = Get-VSCodeArgument -Path 'b', 'a', 'c'

# Assert
Assert-Equal -Expected @('b', 'a', 'c') -Actual $arguments -Message 'Paths keep the order given'

#───────────────────────────────────────────────────────────────────────────────
# Act
$arguments = Get-VSCodeArgument -Path 'one' -Window New

# Assert
Assert-Equal -Expected @('--new-window', 'one') -Actual $arguments -Message '-Window New adds --new-window ahead of the paths'

#───────────────────────────────────────────────────────────────────────────────
# Act
$arguments = Get-VSCodeArgument -Path 'one' -Window Reuse

# Assert
Assert-Equal -Expected @('--reuse-window', 'one') -Actual $arguments -Message '-Window Reuse adds --reuse-window ahead of the paths'

#───────────────────────────────────────────────────────────────────────────────
# Act
$arguments = Get-VSCodeArgument -Path 'C:\My Folder\a b.code-workspace'

# Assert
Assert-Equal -Expected 1 -Actual $arguments.Count -Message 'A path containing spaces stays one argument'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Get-VSCodeArgument -Path 'one' -Window Other } -Message 'An unknown -Window value is refused'

exit (Complete-TestRun)
