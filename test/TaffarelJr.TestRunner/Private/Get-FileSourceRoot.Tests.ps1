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

function Get-ScopedRoot {
    <#
    .SYNOPSIS
        Returns what the module's Get-FileSourceRoot answers, as an array.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string[]]$SourceRoot
    )

    $call = { param($Name, $SourceRoot) Get-FileSourceRoot -Name $Name -SourceRoot $SourceRoot }
    return @(& $module $call $Name $SourceRoot)
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a source folder holding two module folders
$sandbox = New-TestRunnerSandbox
$src = Join-Path $sandbox 'src'
$moduleA = (New-Item -ItemType Directory -Path (Join-Path $src 'TaffarelJr.A')).FullName
$moduleB = (New-Item -ItemType Directory -Path (Join-Path $src 'TaffarelJr.B')).FullName

# Act
$scoped = @(Get-ScopedRoot -Name 'TaffarelJr.A/Public/Get-Thing' -SourceRoot $src)

# Assert
Assert-Equal -Expected @($moduleA) -Actual $scoped `
    -Message 'A first segment that is a folder under the root is measured by that folder alone'

#───────────────────────────────────────────────────────────────────────────────
# Act
$unknown = @(Get-ScopedRoot -Name 'TaffarelJr.C/Get-Thing' -SourceRoot $src)

# Assert
Assert-Equal -Expected @($src) -Actual $unknown `
    -Message 'A first segment that is no folder under the root leaves the root as it is'

#───────────────────────────────────────────────────────────────────────────────
# Act
$flat = @(Get-ScopedRoot -Name 'Get-Thing' -SourceRoot $src)

# Assert
Assert-Equal -Expected @($src) -Actual $flat `
    -Message 'A name with no slash leaves the root as it is'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the module folder only under the second of two roots
$other = (New-Item -ItemType Directory -Path (Join-Path $sandbox 'other')).FullName

# Act
$second = @(Get-ScopedRoot -Name 'TaffarelJr.A/Get-Thing' -SourceRoot @($other, $src))

# Assert
Assert-Equal -Expected @($moduleA) -Actual $second `
    -Message 'The first root that holds the folder gives it, whichever its place in the list'

#───────────────────────────────────────────────────────────────────────────────
# Act - a root that already is the module folder
$already = @(Get-ScopedRoot -Name 'TaffarelJr.A/Get-Thing' -SourceRoot $moduleA)

# Assert
Assert-Equal -Expected @($moduleA) -Actual $already `
    -Message 'A root named for the folder is kept as it is'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same folder, with the separator a path may end in
$trailing = $moduleA + [IO.Path]::DirectorySeparatorChar

# Act
$trimmed = @(Get-ScopedRoot -Name 'TaffarelJr.A/Get-Thing' -SourceRoot $trailing)

# Assert
Assert-Equal -Expected @($trailing) -Actual $trimmed `
    -Message 'A trailing separator does not stop a root being named for the folder'

#───────────────────────────────────────────────────────────────────────────────
# Act - the roots of a run over two modules
$pair = @(Get-ScopedRoot -Name 'TaffarelJr.B/Get-Thing' -SourceRoot @($moduleA, $moduleB))

# Assert
Assert-Equal -Expected @($moduleB) -Actual $pair `
    -Message 'Of several module roots, only the one named for the folder is kept'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a root that holds the folder ahead of a root named for it
$held = New-Item -ItemType Directory -Path (Join-Path $sandbox 'holder' 'TaffarelJr.A')
$holder = $held.Parent.FullName

# Act
$named = @(Get-ScopedRoot -Name 'TaffarelJr.A/Get-Thing' -SourceRoot @($holder, $moduleA))

# Assert
Assert-Equal -Expected @($moduleA) -Actual $named `
    -Message 'A root named for the folder is taken before one that merely holds it'

# Cleanup
Remove-TestRunnerSandbox -Path $sandbox

exit (Complete-TestRun)
