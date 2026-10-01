#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - content and names, across a nested tree, CRLF and BOM preserved
    $root = Join-Path $sandbox 'nested'
    New-Item -ItemType Directory -Path (Join-Path $root 'Placeholder.Sub') | Out-Null
    $filePath = Join-Path $root 'Placeholder.Sub' 'Placeholder.txt'
    [File]::WriteAllText($filePath, "Hello Placeholder`r`n", [UTF8Encoding]::new($true))

    # Act
    $result = Rename-Token -Path $root -From 'Placeholder' -To 'Real'

    # Assert
    $newPath = Join-Path $root 'Real.Sub' 'Real.txt'
    Assert-Equal -Expected 1 -Actual $result.FilesEdited -Message 'The one file containing the token is edited'
    Assert-Equal -Expected 2 -Actual $result.PathsRenamed -Message 'Both the directory and the file are renamed'
    Assert-Equal -Expected ([byte[]](0xEF, 0xBB, 0xBF) + [Encoding]::UTF8.GetBytes("Hello Real`r`n")) `
        -Actual ([File]::ReadAllBytes($newPath)) `
        -Message 'The renamed file holds the new content, with its BOM and CRLF'
    Assert-Equal -Expected 0 -Actual @($result.Warning).Count -Message 'A clean run has nothing to warn about'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a run that has already succeeded
    $again = Join-Path $sandbox 'again'
    New-Item -ItemType Directory -Path $again | Out-Null
    [File]::WriteAllText((Join-Path $again 'Placeholder.txt'), 'Placeholder')
    $null = Rename-Token -Path $again -From 'Placeholder' -To 'Real'

    # Act
    $second = Rename-Token -Path $again -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 0 -Actual $second.FilesEdited -Message 'A re-run after success finds nothing left to edit'
    Assert-Equal -Expected 0 -Actual $second.PathsRenamed -Message 'and nothing left to rename'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $same = Join-Path $sandbox 'same'
    New-Item -ItemType Directory -Path $same | Out-Null
    [File]::WriteAllText((Join-Path $same 'Same.txt'), 'Same')

    # Act
    $noOp = Rename-Token -Path $same -From 'Same' -To 'Same'

    # Assert
    Assert-Equal -Expected 0 -Actual $noOp.FilesEdited -Message '-From equal to -To is a no-op'
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $same 'Same.txt')) -Message 'and nothing is touched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a token that differs from its replacement only in case
    $casing = Join-Path $sandbox 'casing'
    New-Item -ItemType Directory -Path $casing | Out-Null
    [File]::WriteAllText((Join-Path $casing 'file.txt'), 'Placeholder')

    # Act
    $caseOnly = Rename-Token -Path $casing -From 'Placeholder' -To 'placeholder'

    # Assert
    Assert-Equal -Expected 1 -Actual $caseOnly.FilesEdited `
        -Message 'A case-only rename is real work, not treated as already done'
    Assert-Equal -Expected 'placeholder' -Actual ([File]::ReadAllText((Join-Path $casing 'file.txt'))) `
        -Message 'and changes the content'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a name and a folder that need renaming only in their case
    $caseNames = Join-Path $sandbox 'case-names'
    New-Item -ItemType Directory -Path (Join-Path $caseNames 'Placeholder') | Out-Null
    [File]::WriteAllText((Join-Path $caseNames 'Placeholder' 'Placeholder.txt'), 'x')

    # Act
    $null = Rename-Token -Path $caseNames -From 'Placeholder' -To 'placeholder'

    # Assert
    $names = @(Get-ChildItem -LiteralPath $caseNames -Recurse | ForEach-Object Name)
    Assert-Equal -Expected @('placeholder', 'placeholder.txt') -Actual $names `
        -Message 'A directory and a file whose names differ only in case are renamed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an excluded directory
    $excluded = Join-Path $sandbox 'excluded'
    New-Item -ItemType Directory -Path (Join-Path $excluded 'bin') | Out-Null
    [File]::WriteAllText((Join-Path $excluded 'bin' 'Placeholder.txt'), 'Placeholder')

    # Act
    $result = Rename-Token -Path $excluded -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 0 -Actual $result.FilesEdited -Message 'Content under an excluded directory is not edited'
    Assert-Equal -Expected 'Placeholder' -Actual ([File]::ReadAllText((Join-Path $excluded 'bin' 'Placeholder.txt'))) `
        -Message 'and a file under it keeps its name and its content'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - nothing excluded at all
    $open = Join-Path $sandbox 'open'
    New-Item -ItemType Directory -Path (Join-Path $open 'bin') | Out-Null
    [File]::WriteAllText((Join-Path $open 'bin' 'Placeholder.txt'), 'Placeholder')

    # Act
    $result = Rename-Token -Path $open -From 'Placeholder' -To 'Real' -Exclude @()

    # Assert
    Assert-Equal -Expected 1 -Actual $result.FilesEdited `
        -Message 'An empty -Exclude excludes nothing, rather than everything'
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText((Join-Path $open 'bin' 'Real.txt'))) `
        -Message 'so even a folder called bin is searched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file with a skipped extension
    $skipped = Join-Path $sandbox 'skipped'
    New-Item -ItemType Directory -Path $skipped | Out-Null
    [File]::WriteAllText((Join-Path $skipped 'Placeholder.png'), 'Placeholder')

    # Act
    $result = Rename-Token -Path $skipped -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 0 -Actual $result.FilesEdited -Message 'A skip-extension file has its content left alone'
    Assert-Equal -Expected 1 -Actual $result.PathsRenamed -Message 'but is still renamed'
    Assert-Equal -Expected 'Placeholder' -Actual ([File]::ReadAllText((Join-Path $skipped 'Real.png'))) `
        -Message 'with its original content'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an SVG, which is text, with the token in its title
    $vector = Join-Path $sandbox 'vector'
    New-Item -ItemType Directory -Path $vector | Out-Null
    [File]::WriteAllText((Join-Path $vector 'logo.svg'), '<svg><title>Placeholder</title></svg>')

    # Act
    $result = Rename-Token -Path $vector -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 1 -Actual $result.FilesEdited -Message 'An SVG is text, so its content is edited'
    Assert-Equal -Expected '<svg><title>Real</title></svg>' `
        -Actual ([File]::ReadAllText((Join-Path $vector 'logo.svg'))) `
        -Message 'and the token in its title is replaced'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - binary content under an extension nobody listed
    $binaryRoot = Join-Path $sandbox 'binary'
    New-Item -ItemType Directory -Path $binaryRoot | Out-Null
    $binaryPath = New-TestFile -Directory $binaryRoot -Name 'Placeholder.dat' `
        -Byte ([byte[]](0x50, 0x6C, 0x61, 0x63, 0x65, 0x68, 0x6F, 0x6C, 0x64, 0x65, 0x72, 0x00))
    $originalBytes = [File]::ReadAllBytes($binaryPath)

    # Act
    $result = Rename-Token -Path $binaryRoot -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 0 -Actual $result.FilesEdited -Message 'Binary content is not counted as edited'
    Assert-Equal `
        -Expected @("Skipped binary content: $binaryPath") `
        -Actual @($result.Warning) `
        -Message 'and is reported in Warning, by path'
    Assert-Equal -Expected $originalBytes -Actual ([File]::ReadAllBytes((Join-Path $binaryRoot 'Real.dat'))) `
        -Message 'The file is renamed by name, and its bytes survive'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a rename that collides with a file already there
    $collision = Join-Path $sandbox 'collision'
    New-Item -ItemType Directory -Path $collision | Out-Null
    [File]::WriteAllText((Join-Path $collision 'Placeholder.txt'), 'Placeholder')
    [File]::WriteAllText((Join-Path $collision 'Real.txt'), 'already here')
    [File]::WriteAllText((Join-Path $collision 'OtherPlaceholder.txt'), 'Placeholder')

    # Act / Assert
    Assert-Throws -ScriptBlock { Rename-Token -Path $collision -From 'Placeholder' -To 'Real' } `
        -MessageLike "*Could not rename 'Placeholder' -> 'Real' in 1 item(s)*", '*Placeholder.txt -> Real.txt*' `
        -Message 'A collision throws at the end, naming both paths'
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $collision 'OtherReal.txt')) `
        -Message 'but an unrelated item is still renamed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a read-only file with the token beside an ordinary one
    $locked = Join-Path $sandbox 'locked'
    New-Item -ItemType Directory -Path $locked | Out-Null
    $lockedFile = Join-Path $locked 'locked.txt'
    [File]::WriteAllText($lockedFile, 'Placeholder')
    Set-ItemProperty -LiteralPath $lockedFile -Name IsReadOnly -Value $true
    [File]::WriteAllText((Join-Path $locked 'normal.txt'), 'Placeholder')

    # Act / Assert
    Assert-Throws -ScriptBlock { Rename-Token -Path $locked -From 'Placeholder' -To 'Real' } `
        -MessageLike '*in 1 item(s)*', '*locked.txt - *' `
        -Message 'A file that cannot be written is named in the error'
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText((Join-Path $locked 'normal.txt'))) `
        -Message 'but the other files are still done'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - text in Windows-1252: one file with the token, one without
    $legacy = Join-Path $sandbox 'legacy'
    New-Item -ItemType Directory -Path $legacy | Out-Null
    $latinWith = New-TestFile -Directory $legacy -Name 'with.txt' `
        -Byte ([Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9) Placeholder"))
    $latinWithout = New-TestFile -Directory $legacy -Name 'without.txt' `
        -Byte ([Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9)"))
    [File]::WriteAllText((Join-Path $legacy 'normal.txt'), 'Placeholder')
    $withBytes = [File]::ReadAllBytes($latinWith)
    $withoutBytes = [File]::ReadAllBytes($latinWithout)

    # Act / Assert
    Assert-Throws -ScriptBlock { Rename-Token -Path $legacy -From 'Placeholder' -To 'Real' } `
        -MessageLike '*in 1 item(s)*', '*with.txt*is not valid utf-8 text*' `
        -Message 'Text that has the token but is not valid UTF-8 is a failure, naming the file'
    Assert-Equal -Expected $withBytes -Actual ([File]::ReadAllBytes($latinWith)) `
        -Message 'and is not rewritten with replacement characters'
    Assert-Equal -Expected $withoutBytes -Actual ([File]::ReadAllBytes($latinWithout)) `
        -Message 'Such a file without the token is not a problem, and is left alone'
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText((Join-Path $legacy 'normal.txt'))) `
        -Message 'and the ordinary files are still done'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - UTF-16 and UTF-32 files in one tree
    $wide = Join-Path $sandbox 'wide'
    New-Item -ItemType Directory -Path $wide | Out-Null
    [File]::WriteAllText((Join-Path $wide 'u16.txt'), "Placeholder`r`n", [UnicodeEncoding]::new($false, $true))
    [File]::WriteAllText((Join-Path $wide 'u32.txt'), "Placeholder`r`n", [UTF32Encoding]::new($true, $true))

    # Act
    $result = Rename-Token -Path $wide -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 2 -Actual $result.FilesEdited -Message 'Both files are edited'
    Assert-Equal -Expected ([byte[]](0xFF, 0xFE) + [UnicodeEncoding]::new($false, $false).GetBytes("Real`r`n")) `
        -Actual ([File]::ReadAllBytes((Join-Path $wide 'u16.txt'))) `
        -Message 'and stay UTF-16'
    Assert-Equal `
        -Expected ([byte[]](0x00, 0x00, 0xFE, 0xFF) + [UTF32Encoding]::new($true, $false).GetBytes("Real`r`n")) `
        -Actual ([File]::ReadAllBytes((Join-Path $wide 'u32.txt'))) `
        -Message 'or UTF-32'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a new name that contains the old one
    $contained = Join-Path $sandbox 'contained'
    New-Item -ItemType Directory -Path $contained | Out-Null
    [File]::WriteAllText((Join-Path $contained 'Foo.txt'), 'Foo')

    # Act / Assert
    Assert-Throws -ScriptBlock { Rename-Token -Path $contained -From 'Foo' -To 'FooBar' } `
        -MessageLike "*Cannot rename 'Foo' to 'FooBar'*", '*re-run would rename it again*', '*-Force*' `
        -Message 'A new name containing the old one is refused, saying why and how to override'
    Assert-Equal -Expected 'Foo' -Actual ([File]::ReadAllText((Join-Path $contained 'Foo.txt'))) `
        -Message 'and nothing is changed'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $forced = Rename-Token -Path $contained -From 'Foo' -To 'FooBar' -Force

    # Assert
    Assert-Equal -Expected 'FooBar' -Actual ([File]::ReadAllText((Join-Path $contained 'FooBar.txt'))) `
        -Message '-Force does it anyway, once'
    Assert-Equal -Expected 1 -Actual $forced.FilesEdited -Message 'and counts it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an illegal target name
    $illegal = Join-Path $sandbox 'illegal'
    New-Item -ItemType Directory -Path $illegal | Out-Null
    [File]::WriteAllText((Join-Path $illegal 'file.txt'), 'Placeholder')
    $illegalChar = [Path]::GetInvalidFileNameChars()[0]

    # Act / Assert
    Assert-Throws -ScriptBlock { Rename-Token -Path $illegal -From 'Placeholder' -To "bad${illegalChar}name" } `
        -MessageLike "*Cannot rename 'Placeholder' to*not a legal file name*" `
        -Message 'An illegal target name is refused up front'
    Assert-Equal -Expected 'Placeholder' -Actual ([File]::ReadAllText((Join-Path $illegal 'file.txt'))) `
        -Message 'before anything was changed'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - parameters that cannot work
    Assert-Throws `
        -ScriptBlock { Rename-Token -Path (Join-Path $sandbox 'missing-folder') -From 'A' -To 'B' } `
        -MessageLike "*'*missing-folder' is not a folder.*" `
        -Message 'A missing folder is named'
    Assert-Throws `
        -ScriptBlock { Rename-Token -Path (Join-Path $same 'Same.txt') -From 'A' -To 'B' } `
        -MessageLike "*'*Same.txt' is not a folder.*" `
        -Message 'and so is a file, which is not a folder either'
    Assert-Throws `
        -ScriptBlock { Rename-Token -Path Env:\ -From 'A' -To 'B' } `
        -MessageLike "*'Env:\' is not a file system path*" `
        -Message 'A folder that is not on the file system is refused before anything is listed'
    Assert-Throws -ScriptBlock { Rename-Token -Path $same -From 'A' -To 'B' -SkipExtension 'png' } `
        -MessageLike "*an extension starts with a dot*'png'*" `
        -Message 'An extension with no dot is refused, since it would silently match nothing'
    Assert-Throws -ScriptBlock { Rename-Token -Path $same -From ' ' -To 'B' } -MessageLike '*From*' `
        -Message 'A blank token is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - PowerShell is in one folder and the process in another
    $relativeRoot = Join-Path $sandbox 'relative'
    $elsewhere = Join-Path $sandbox 'elsewhere'
    New-Item -ItemType Directory -Path $relativeRoot, $elsewhere | Out-Null
    [File]::WriteAllText((Join-Path $relativeRoot 'Placeholder.txt'), 'Placeholder')

    # Act
    $relative = Use-SplitLocation -Location $sandbox -ProcessDirectory $elsewhere `
        -ScriptBlock { Rename-Token -Path .\relative -From 'Placeholder' -To 'Real' }

    # Assert
    Assert-Equal -Expected 1 -Actual $relative.FilesEdited -Message 'A relative -Path is searched where PowerShell is'
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText((Join-Path $relativeRoot 'Real.txt'))) `
        -Message 'and its files are the ones changed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file in the tree with a second name, a hard link, outside it
    $hardLinked = Join-Path $sandbox 'hard-linked'
    New-Item -ItemType Directory -Path $hardLinked | Out-Null
    $hardLinkedFile = Join-Path $hardLinked 'a.txt'
    [File]::WriteAllText($hardLinkedFile, 'Placeholder')
    $null = New-Item -ItemType HardLink -Path (Join-Path $sandbox 'second-name.txt') -Target $hardLinkedFile

    # Act
    $hardResult = Rename-Token -Path $hardLinked -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal `
        -Expected 1 `
        -Actual $hardResult.FilesEdited `
        -Message 'A hard-linked file is an ordinary file, and is edited'
    Assert-Equal `
        -Expected 'Real' `
        -Actual ([File]::ReadAllText($hardLinkedFile)) `
        -Message 'so the tree no longer holds the old name'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a hidden file with the token
    $hiddenRoot = Join-Path $sandbox 'hidden-root'
    New-Item -ItemType Directory -Path $hiddenRoot | Out-Null
    $hiddenFile = Join-Path $hiddenRoot '.settings'
    [File]::WriteAllText($hiddenFile, 'Placeholder')
    (Get-Item -LiteralPath $hiddenFile -Force).Attributes = 'Hidden'

    # Act
    $hiddenResult = Rename-Token -Path $hiddenRoot -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 1 -Actual $hiddenResult.FilesEdited -Message 'A hidden file is edited like any other'
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText($hiddenFile)) -Message 'and holds the new name'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $byPosition = Join-Path $sandbox 'by-position'
    New-Item -ItemType Directory -Path $byPosition | Out-Null
    [File]::WriteAllText((Join-Path $byPosition 'file.txt'), 'Placeholder')

    # Act
    $positional = Rename-Token $byPosition -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 1 -Actual $positional.FilesEdited -Message 'The folder can be given by position'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder that cannot be listed (last: the stand-in listing stays)
    $partial = Join-Path $sandbox 'partial'
    $unlisted = Join-Path $partial 'unlisted'
    New-Item -ItemType Directory -Path $unlisted | Out-Null
    [File]::WriteAllText((Join-Path $partial 'file.txt'), 'Placeholder')
    Install-DirectoryListingStub -Module (Get-Module TaffarelJr.FileText) -FailFor $unlisted

    # Act
    $partialResult = Rename-Token -Path $partial -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal `
        -Expected @("Not searched: $unlisted - Access to the path is denied.") `
        -Actual @($partialResult.Warning) `
        -Message 'A folder that could not be searched is named in Warning: a partial run is not a full one'
    Assert-Equal -Expected 1 -Actual $partialResult.FilesEdited -Message 'and the rest of the tree is still done'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
