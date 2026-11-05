#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')
$module = Get-Module TaffarelJr.FileText

function Get-Candidate([string]$Path, [string[]]$Exclude) {
    & $module { param($p, $e) Get-TokenCandidate -Path $p -Exclude $e } $Path $Exclude
}

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tree with an excluded subdirectory
    $tree = Join-Path $sandbox 'tree'
    New-Item -ItemType Directory -Path (Join-Path $tree 'bin') | Out-Null
    [File]::WriteAllText((Join-Path $tree 'bin' 'inside.txt'), 'x')
    [File]::WriteAllText((Join-Path $tree 'outside.txt'), 'x')

    # Act
    $result = Get-Candidate -Path $tree -Exclude @('bin')

    # Assert
    Assert-Equal -Expected @('outside.txt') -Actual @($result.Item | ForEach-Object Name) `
        -Message 'Only the item outside the excluded directory is a candidate'
    Assert-Equal -Expected 0 -Actual @($result.Warning).Count -Message 'A fully readable tree has nothing to warn about'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a root that itself lives under a folder with the excluded name
    $nestedRoot = Join-Path $tree 'bin' 'nested-root'
    New-Item -ItemType Directory -Path $nestedRoot | Out-Null
    [File]::WriteAllText((Join-Path $nestedRoot 'file.txt'), 'x')

    # Act
    $nested = Get-Candidate -Path $nestedRoot -Exclude @('bin')

    # Assert
    Assert-Equal -Expected @('file.txt') -Actual @($nested.Item | ForEach-Object Name) `
        -Message 'Only what is inside the root counts, so a root under a folder called bin still finds its own contents'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tree with a deep excluded folder and a lot in it
    $deep = Join-Path $sandbox 'deep'
    New-Item -ItemType Directory -Path (Join-Path $deep 'src' 'node_modules' 'pkg' 'lib') | Out-Null
    [File]::WriteAllText((Join-Path $deep 'src' 'node_modules' 'pkg' 'lib' 'x.js'), 'x')
    [File]::WriteAllText((Join-Path $deep 'src' 'real.txt'), 'x')
    Install-DirectoryListingStub -Module $module

    # Act
    $deepResult = Get-Candidate -Path $deep -Exclude @('node_modules')
    $visited = @(Get-VisitedFolder -Module $module)

    # Assert
    Assert-Equal -Expected @('real.txt', 'src') -Actual @($deepResult.Item | ForEach-Object Name | Sort-Object) `
        -Message 'An excluded folder is skipped at any depth'
    Assert-Equal -Expected @($deep, (Join-Path $deep 'src')) -Actual @($visited | Sort-Object) `
        -Message 'and is never entered, so what is inside it costs nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an empty exclusion list, and a folder called bin
    # (same tree as the first case)

    # Act
    $open = Get-Candidate -Path $tree -Exclude @()

    # Assert
    Assert-Equal -Expected @('bin', 'inside.txt', 'nested-root', 'file.txt', 'outside.txt' | Sort-Object) `
        -Actual @($open.Item | ForEach-Object Name | Sort-Object) `
        -Message 'An empty exclusion list excludes nothing, rather than everything'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - names that merely contain, or look like, an excluded name
    $names = Join-Path $sandbox 'names'
    New-Item -ItemType Directory -Path (Join-Path $names '.github'), (Join-Path $names 'binary'), (Join-Path $names 'a+b'), (Join-Path $names 'aab'), (Join-Path $names 'BIN') | Out-Null
    [File]::WriteAllText((Join-Path $names 'secret.txt'), 'x')
    [File]::WriteAllText((Join-Path $names 'secret.txt.bak'), 'x')

    # Act
    $namesResult = Get-Candidate -Path $names -Exclude @('.git', 'bin', 'a+b', 'secret.txt')

    # Assert
    Assert-Equal -Expected @('.github', 'aab', 'binary', 'secret.txt.bak') `
        -Actual @($namesResult.Item | ForEach-Object Name | Sort-Object) `
        -Message 'An excluded name is matched whole and literally: .github, binary, aab, and secret.txt.bak survive; .git, a+b, secret.txt, and a folder called BIN are excluded'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder that cannot be listed, beside one that can
    $blocked = Join-Path $sandbox 'blocked'
    New-Item -ItemType Directory -Path (Join-Path $blocked 'locked'), (Join-Path $blocked 'fine') | Out-Null
    [File]::WriteAllText((Join-Path $blocked 'locked' 'hidden.txt'), 'x')
    [File]::WriteAllText((Join-Path $blocked 'fine' 'seen.txt'), 'x')
    Install-DirectoryListingStub -Module $module -FailFor (Join-Path $blocked 'locked')

    # Act
    $blockedResult = Get-Candidate -Path $blocked -Exclude @()

    # Assert
    Assert-Equal -Expected @("Not searched: $(Join-Path $blocked 'locked') - Access to the path is denied.") `
        -Actual @($blockedResult.Warning) `
        -Message 'A folder that could not be listed is reported by name, with the reason'
    Assert-Equal -Expected @('fine', 'locked', 'seen.txt') `
        -Actual @($blockedResult.Item | ForEach-Object Name | Sort-Object) `
        -Message 'and the rest of the tree is still searched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an excluded folder that could not be listed either
    $quiet = Join-Path $sandbox 'quiet'
    New-Item -ItemType Directory -Path (Join-Path $quiet 'obj') | Out-Null
    Install-DirectoryListingStub -Module $module -FailFor (Join-Path $quiet 'obj')

    # Act
    $quietResult = Get-Candidate -Path $quiet -Exclude @('obj')

    # Assert
    Assert-Equal -Expected 0 -Actual @($quietResult.Warning).Count `
        -Message 'A folder that is excluded is never listed, so it cannot raise a warning'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - hidden items, and a root given with a trailing separator
    $hiddenRoot = Join-Path $sandbox 'hidden-root'
    New-Item -ItemType Directory -Path $hiddenRoot | Out-Null
    $hiddenFile = Join-Path $hiddenRoot '.dotfile'
    [File]::WriteAllText($hiddenFile, 'x')
    (Get-Item -LiteralPath $hiddenFile -Force).Attributes = 'Hidden'

    # Act
    $hiddenResult = Get-Candidate -Path "$hiddenRoot$([Path]::DirectorySeparatorChar)" -Exclude @()

    # Assert
    Assert-Equal -Expected @('.dotfile') -Actual @($hiddenResult.Item | ForEach-Object Name) `
        -Message 'Hidden items are candidates, and a trailing separator on the root is harmless'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $emptyRoot = Join-Path $sandbox 'empty-root'
    New-Item -ItemType Directory -Path $emptyRoot | Out-Null

    # Act
    $emptyResult = Get-Candidate -Path $emptyRoot -Exclude @('bin')

    # Assert
    Assert-Equal -Expected 0 -Actual @($emptyResult.Item).Count -Message 'An empty tree has no candidates'
    Assert-Equal -Expected 0 -Actual @($emptyResult.Warning).Count -Message 'and nothing to warn about'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
