#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Select-UniqueFile.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Find-TestFile.ps1')
. (Join-Path $PSScriptRoot '..' 'TestRunnerTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$root = New-TestRunnerSandbox
New-TestFileStub -Directory $root -Name 'A' | Out-Null
New-TestFileStub -Directory (Join-Path $root 'Sub') -Name 'B' | Out-Null
Set-Content -LiteralPath (Join-Path $root 'NotATest.ps1') -Value ''
Set-Content -LiteralPath (Join-Path $root 'C.Tests.ps1x') -Value ''
Set-Content -LiteralPath (Join-Path $root 'D.Tests.ps1.bak') -Value ''

# Act
$files = @(Find-TestFile -Path $root)

# Assert
Assert-Equal -Expected 2 -Actual $files.Count `
    -Message 'Finds every *.Tests.ps1 recursively, ignoring non-test files and near-misses'
Assert-Equal -Expected 'A.Tests.ps1' -Actual $files[0].Name -Message 'Results are sorted by full path'
Assert-Equal -Expected 'B.Tests.ps1' -Actual $files[1].Name `
    -Message 'A nested file sorts after its parent-level sibling'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Filter narrows by file name
$filtered = @(Find-TestFile -Path $root -Filter 'A')

# Assert
Assert-Equal -Expected 1 -Actual $filtered.Count -Message '-Filter narrows to matching file names'
Assert-Equal -Expected 'A.Tests.ps1' -Actual $filtered[0].Name -Message 'The filtered result is the expected file'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an empty folder
$emptyRoot = New-TestRunnerSandbox
$empty = @(Find-TestFile -Path $emptyRoot)

# Assert
Assert-Equal -Expected 0 -Actual $empty.Count `
    -Message 'An empty folder returns zero files, so @() collects an empty array'
Assert-That -Condition ($null -eq (Find-TestFile -Path $emptyRoot)) -Message 'and a bare capture is $null'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - several folders searched in one call
$second = New-TestRunnerSandbox
New-TestFileStub -Directory $second -Name 'C' | Out-Null
$combined = @(Find-TestFile -Path @($root, $second))

# Assert
Assert-Equal -Expected 3 -Actual $combined.Count -Message 'Every given folder is searched, results combined'
Assert-That -Condition ($combined.Name -contains 'C.Tests.ps1') -Message 'A file from the second folder is included too'

#───────────────────────────────────────────────────────────────────────────────
# Act - a folder given along with one of its own subfolders
$nested = @(Find-TestFile -Path @($root, (Join-Path $root 'Sub')))

# Assert
Assert-Equal -Expected 2 -Actual $nested.Count -Message 'A file under two of the given folders is found once, not twice'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a hidden file, and a file in a folder whose name starts with a dot,
# hidden too wherever a dot alone does not hide it
$hiddenRoot = New-TestRunnerSandbox
$hiddenFile = Get-Item -LiteralPath (New-TestFileStub -Directory $hiddenRoot -Name 'Hidden')
$dotFolder = Join-Path $hiddenRoot '.dotted'
New-TestFileStub -Directory $dotFolder -Name 'Dotted' | Out-Null
if ($IsWindows) {
    $hiddenFile.Attributes = $hiddenFile.Attributes -bor [IO.FileAttributes]::Hidden
    $dotItem = Get-Item -LiteralPath $dotFolder
    $dotItem.Attributes = $dotItem.Attributes -bor [IO.FileAttributes]::Hidden
}

# Act
$hidden = @(Find-TestFile -Path $hiddenRoot)

# Assert
Assert-Equal -Expected @('Dotted.Tests.ps1', 'Hidden.Tests.ps1') -Actual @($hidden.Name | Sort-Object) `
    -Message 'Hidden files and folders are searched too, on every platform'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a unit test file beside a *.Live one and a *.Contract one
$tiers = New-TestRunnerSandbox
New-TestFileStub -Directory $tiers -Name 'Get-A' | Out-Null
New-TestFileStub -Directory $tiers -Name 'Get-A.Live' | Out-Null
New-TestFileStub -Directory $tiers -Name 'Get-B.Contract' | Out-Null

# Act
$withoutLive = @(Find-TestFile -Path $tiers -Exclude '*.Live')

# Assert
Assert-Equal -Expected @('Get-A.Tests.ps1', 'Get-B.Contract.Tests.ps1') `
    -Actual @($withoutLive.Name) -Message '-Exclude leaves out a file whose name matches it'

#───────────────────────────────────────────────────────────────────────────────
# Act
$unitOnly = @(Find-TestFile -Path $tiers -Exclude '*.Live', '*.Contract')

# Assert
Assert-Equal -Expected @('Get-A.Tests.ps1') -Actual @($unitOnly.Name) `
    -Message 'A file matching any one of several -Exclude patterns is left out'

#───────────────────────────────────────────────────────────────────────────────
# Act
$noneExcluded = @(Find-TestFile -Path $tiers -Exclude 'Nothing*')

# Assert
Assert-Equal -Expected @('Get-A.Live.Tests.ps1', 'Get-A.Tests.ps1', 'Get-B.Contract.Tests.ps1') `
    -Actual @($noneExcluded.Name) -Message 'A pattern that matches no file leaves every file in'

#───────────────────────────────────────────────────────────────────────────────
# Act
$lowerCase = @(Find-TestFile -Path $tiers -Exclude '*.live')

# Assert
Assert-Equal -Expected @('Get-A.Tests.ps1', 'Get-B.Contract.Tests.ps1') -Actual @($lowerCase.Name) `
    -Message '-Exclude matches without regard to case'

#───────────────────────────────────────────────────────────────────────────────
# Act
$narrowed = @(Find-TestFile -Path $tiers -Filter 'Get-A*' -Exclude '*.Live')

# Assert
Assert-Equal -Expected @('Get-A.Tests.ps1') -Actual @($narrowed.Name) `
    -Message '-Exclude applies to the files -Filter found'

#───────────────────────────────────────────────────────────────────────────────
# Act
$oneCharacter = @(Find-TestFile -Path $tiers -Exclude 'Get-?')

# Assert
Assert-Equal -Expected @('Get-A.Live.Tests.ps1', 'Get-B.Contract.Tests.ps1') `
    -Actual @($oneCharacter.Name) -Message 'A ? in -Exclude stands for exactly one character'

#───────────────────────────────────────────────────────────────────────────────
# Act - a bracket is a character, not a range
$bracketed = @(Find-TestFile -Path $tiers -Exclude 'Get-[A]')

# Assert
Assert-Equal -Expected @('Get-A.Live.Tests.ps1', 'Get-A.Tests.ps1', 'Get-B.Contract.Tests.ps1') `
    -Actual @($bracketed.Name) `
    -Message 'A [ in -Exclude is literal, so a pattern naming no real file leaves every file in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file whose name holds a backtick, which PowerShell wildcards use to escape
$tickRoot = New-TestRunnerSandbox
New-TestFileStub -Directory $tickRoot -Name 'Back`tick' | Out-Null
New-TestFileStub -Directory $tickRoot -Name 'Backtick' | Out-Null

# Act
$ticked = @(Find-TestFile -Path $tickRoot -Exclude 'Back`tick')

# Assert
Assert-Equal -Expected @('Backtick.Tests.ps1') -Actual @($ticked.Name) `
    -Message 'A backtick in -Exclude is literal, so only the file with one in its name is left out'

# Cleanup
Remove-TestRunnerSandbox -Path $root
Remove-TestRunnerSandbox -Path $emptyRoot
Remove-TestRunnerSandbox -Path $second
Remove-TestRunnerSandbox -Path $hiddenRoot
Remove-TestRunnerSandbox -Path $tiers
Remove-TestRunnerSandbox -Path $tickRoot

exit (Complete-TestRun)
