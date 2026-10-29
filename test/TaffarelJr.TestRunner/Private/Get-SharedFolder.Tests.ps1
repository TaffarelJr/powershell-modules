#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'TestRunnerTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder with two subfolders, one of them nested further
$sandbox = New-TestRunnerSandbox
$left = New-Item -ItemType Directory -Path (Join-Path $sandbox 'left')
$right = New-Item -ItemType Directory -Path (Join-Path $sandbox 'right' 'deeper')

# Act
$alone = & $module { param($Path) Get-SharedFolder -Path $Path } @($left.FullName)
$siblings = & $module { param($Path) Get-SharedFolder -Path $Path } @($left.FullName, $right.FullName)
$nested = & $module { param($Path) Get-SharedFolder -Path $Path } @($left.Parent.FullName, $right.FullName)

# Assert
Assert-Equal -Expected $left.FullName -Actual $alone -Message 'One folder is its own shared folder'
Assert-Equal -Expected $sandbox -Actual $siblings -Message 'Two folders share the deepest folder holding both'
Assert-Equal -Expected $sandbox -Actual $nested -Message 'A folder holding the other is the shared one'

#───────────────────────────────────────────────────────────────────────────────
# Act - folders that do not exist yet
$missing = & $module { param($Path) Get-SharedFolder -Path $Path } @(Join-Path $sandbox 'right' 'none' 'deep')

# Assert
Assert-Equal -Expected (Join-Path $sandbox 'right') -Actual $missing `
    -Message 'A folder that does not exist is held by its nearest existing parent'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a path under a folder named two dots and a zero-width joiner, which a
# comparison that ignores such characters would read as climbing out
$joiner = [string][char]0x200D
$joined = Join-Path $sandbox "..$joiner" 'inside'

# Act
$joinedShared = & $module { param($Path) Get-SharedFolder -Path $Path } @($sandbox, $joined)

# Assert
Assert-Equal -Expected $sandbox -Actual $joinedShared `
    -Message 'A folder named two dots and a zero-width joiner is held by the folder it is in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - paths on different drives, which only Windows has
if ($IsWindows) {
    $otherDrive = 'Q:\nowhere'
    $none = & $module { param($Path) Get-SharedFolder -Path $Path } @($left.FullName, $otherDrive)
    Assert-Equal -Expected $null -Actual $none -Message 'Paths on different drives share no folder'
}

# Cleanup
Remove-TestRunnerSandbox -Path $sandbox

exit (Complete-TestRun)
