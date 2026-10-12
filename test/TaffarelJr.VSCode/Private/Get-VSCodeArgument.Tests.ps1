#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-VSCodeArgument.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act
$arguments = @(Get-VSCodeArgument -Path 'one')
$bare = Get-VSCodeArgument -Path 'one'

# Assert
Assert-Equal -Expected 'one' -Actual $bare `
    -Message 'A single path is streamed as that one argument, not wrapped in an array'
Assert-Equal -Expected @('one') -Actual $arguments -Message 'Without -Window, the path is the only argument'

#───────────────────────────────────────────────────────────────────────────────
# Act
$arguments = @(Get-VSCodeArgument -Path 'b', 'a', 'c')

# Assert
Assert-Equal -Expected @('b', 'a', 'c') -Actual $arguments -Message 'Paths keep the order given'

#───────────────────────────────────────────────────────────────────────────────
# Act
$arguments = @(Get-VSCodeArgument -Path 'one' -Window New)

# Assert
Assert-Equal -Expected @('--new-window', 'one') -Actual $arguments `
    -Message '-Window New adds --new-window ahead of the paths'

#───────────────────────────────────────────────────────────────────────────────
# Act
$arguments = @(Get-VSCodeArgument -Path 'one' -Window Reuse)

# Assert
Assert-Equal -Expected @('--reuse-window', 'one') -Actual $arguments `
    -Message '-Window Reuse adds --reuse-window ahead of the paths'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock {
    Get-VSCodeArgument -Path 'one' -Window Other
} -MessageLike '*Window*does not belong to the set*' -Message 'An unknown -Window value is refused'

exit (Complete-TestRun)
