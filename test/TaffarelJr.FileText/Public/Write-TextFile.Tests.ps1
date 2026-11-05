#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')

$utf8Bom = [byte[]](0xEF, 0xBB, 0xBF)

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a brand new file with no reference
    $newPath = Join-Path $sandbox 'new.txt'

    # Act
    Write-TextFile -Path $newPath -Line @('a', 'b')

    # Assert
    $bytes = [File]::ReadAllBytes($newPath)
    Assert-Equal -Expected ([Encoding]::UTF8.GetBytes('a' + [Environment]::NewLine + 'b' + [Environment]::NewLine)) `
        -Actual $bytes `
        -Message 'A new file with nothing to match is UTF-8 with no BOM, the lines joined and ended with the platform line ending'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an existing CRLF, UTF-8-BOM file
    $existingPath = Join-Path $sandbox 'existing.txt'
    [File]::WriteAllText($existingPath, "old content`r`n", [UTF8Encoding]::new($true))

    # Act - overwrite it with -Line
    Write-TextFile -Path $existingPath -Line @('x', 'y')

    # Assert
    Assert-Equal -Expected ($utf8Bom + [Encoding]::UTF8.GetBytes("x`r`ny`r`n")) `
        -Actual ([File]::ReadAllBytes($existingPath)) `
        -Message 'Rewriting an existing file keeps its BOM and its CRLF'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - -Content is written exactly as given, no line ending appended
    $contentPath = Join-Path $sandbox 'content.txt'
    Write-TextFile -Path $contentPath -Content 'no trailing newline'

    # Assert
    Assert-Equal -Expected 'no trailing newline' -Actual ([File]::ReadAllText($contentPath)) `
        -Message '-Content is written exactly as given'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a sibling that is UTF-8 with a BOM and CRLF
    $likePath = Join-Path $sandbox 'like-source.txt'
    [File]::WriteAllText($likePath, "a`r`n", [UTF8Encoding]::new($true))
    $newViaLike = Join-Path $sandbox 'new-via-like.txt'

    # Act - -LikeFilePath supplies encoding and line ending only when -Path does not exist yet
    Write-TextFile -Path $newViaLike -Line @('z') -LikeFilePath $likePath

    # Assert
    Assert-Equal -Expected ($utf8Bom + [Encoding]::UTF8.GetBytes("z`r`n")) -Actual ([File]::ReadAllBytes($newViaLike)) `
        -Message 'A new file takes its encoding and its line ending from -LikeFilePath'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - -LikeFilePath points at a very different file
    $noBomLfPath = Join-Path $sandbox 'no-bom-lf.txt'
    [File]::WriteAllText($noBomLfPath, "a`n", [UTF8Encoding]::new($false))

    # Act
    Write-TextFile -Path $existingPath -Line @('after') -LikeFilePath $noBomLfPath

    # Assert
    Assert-Equal -Expected ($utf8Bom + [Encoding]::UTF8.GetBytes("after`r`n")) `
        -Actual ([File]::ReadAllBytes($existingPath)) `
        -Message '-LikeFilePath is ignored once -Path has content of its own'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file that exists but is empty, so has nothing to preserve
    $emptyPath = New-TestFile -Directory $sandbox -Name 'empty.txt' -Byte ([byte[]]@())

    # Act
    Write-TextFile -Path $emptyPath -Line @('a') -LikeFilePath $likePath

    # Assert
    Assert-Equal -Expected ($utf8Bom + [Encoding]::UTF8.GetBytes("a`r`n")) -Actual ([File]::ReadAllBytes($emptyPath)) `
        -Message 'An empty file takes the sibling''s encoding and line ending instead of defaulting'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a sibling that is itself empty
    $emptyLike = New-TestFile -Directory $sandbox -Name 'empty-like.txt' -Byte ([byte[]]@())
    $fallbackPath = Join-Path $sandbox 'fallback.txt'

    # Act
    Write-TextFile -Path $fallbackPath -Line @('a') -LikeFilePath $emptyLike

    # Assert
    Assert-Equal -Expected ([Encoding]::UTF8.GetBytes('a' + [Environment]::NewLine)) `
        -Actual ([File]::ReadAllBytes($fallbackPath)) `
        -Message 'An empty sibling has nothing to copy either, so the defaults apply'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an existing UTF-16 and an existing UTF-32 file
    $utf16 = Join-Path $sandbox 'utf16.txt'
    $utf32 = Join-Path $sandbox 'utf32.txt'
    [File]::WriteAllText($utf16, "old`r`n", [UnicodeEncoding]::new($false, $true))
    [File]::WriteAllText($utf32, "old`r`n", [UTF32Encoding]::new($true, $true))

    # Act
    Write-TextFile -Path $utf16 -Line @('x')
    Write-TextFile -Path $utf32 -Line @('x')

    # Assert
    Assert-Equal -Expected ([byte[]](0xFF, 0xFE) + [UnicodeEncoding]::new($false, $false).GetBytes("x`r`n")) `
        -Actual ([File]::ReadAllBytes($utf16)) `
        -Message 'A UTF-16 file stays UTF-16, with its mark'
    Assert-Equal -Expected ([byte[]](0x00, 0x00, 0xFE, 0xFF) + [UTF32Encoding]::new($true, $false).GetBytes("x`r`n")) `
        -Actual ([File]::ReadAllBytes($utf32)) `
        -Message 'A UTF-32 file stays UTF-32, with its mark, in its byte order'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an existing file, written over with an encoding chosen by the caller
    $changed = Join-Path $sandbox 'changed.txt'
    [File]::WriteAllText($changed, "old`r`n", [UTF8Encoding]::new($true))

    # Act
    Write-TextFile -Path $changed -Content 'abc' -Encoding ([UnicodeEncoding]::new($false, $true))
    $brandNew = Join-Path $sandbox 'chosen.txt'
    Write-TextFile -Path $brandNew -Content "caf$([char]0xE9)" -Encoding ([Encoding]::GetEncoding(28591))

    # Assert
    Assert-Equal -Expected ([byte[]](0xFF, 0xFE, 0x61, 0x00, 0x62, 0x00, 0x63, 0x00)) `
        -Actual ([File]::ReadAllBytes($changed)) `
        -Message '-Encoding wins over the encoding the file had'
    Assert-Equal -Expected ([byte[]](0x63, 0x61, 0x66, 0xE9)) -Actual ([File]::ReadAllBytes($brandNew)) `
        -Message 'and over the default for a new file, so a Latin-1 file can be written back as Latin-1'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a CRLF file and an LF file
    $crlfPath = Join-Path $sandbox 'crlf.txt'
    $lfPath = Join-Path $sandbox 'lf.txt'
    [File]::WriteAllText($crlfPath, "old`r`n")
    [File]::WriteAllText($lfPath, "old`n")

    # Act - a line that has a break of its own
    Write-TextFile -Path $crlfPath -Line @("a`nb", "c`r`nd", 'e')
    Write-TextFile -Path $lfPath -Line @("a`r`nb", 'c')

    # Assert
    Assert-Equal -Expected "a`r`nb`r`nc`r`nd`r`ne`r`n" -Actual ([File]::ReadAllText($crlfPath)) `
        -Message 'Every break inside the lines becomes the file''s CRLF, so there is only one kind in the file'
    Assert-Equal -Expected "a`nb`nc`n" -Actual ([File]::ReadAllText($lfPath)) `
        -Message 'and every one becomes LF in an LF file'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file with a stray CRLF among LFs
    $mixedPath = Join-Path $sandbox 'mixed.txt'
    [File]::WriteAllText($mixedPath, "a`nb`nc`nd`r`n")

    # Act
    Write-TextFile -Path $mixedPath -Line @('x', 'y')

    # Assert
    Assert-Equal -Expected "x`ny`n" -Actual ([File]::ReadAllText($mixedPath)) `
        -Message 'A mostly-LF file is not converted to CRLF by one stray line'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - PowerShell is in one folder and the process in another
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null

    # Act
    Use-SplitLocation -Location $here -ProcessDirectory $there `
        -ScriptBlock { Write-TextFile -Path .\out.txt -Content 'x' }

    # Assert
    Assert-That -Condition (Test-Path -LiteralPath (Join-Path $here 'out.txt')) `
        -Message 'A relative path is written in PowerShell''s location'
    Assert-That -Condition (-not (Test-Path -LiteralPath (Join-Path $there 'out.txt'))) `
        -Message 'and not in the process''s working directory'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative -Path that exists, while the two folders disagree
    [File]::WriteAllText((Join-Path $here 'existing.txt'), "old`r`n", [UTF8Encoding]::new($true))
    [File]::WriteAllText((Join-Path $there 'existing.txt'), "old`n")

    # Act
    Use-SplitLocation -Location $here -ProcessDirectory $there `
        -ScriptBlock { Write-TextFile -Path .\existing.txt -Line @('q') }

    # Assert
    Assert-Equal -Expected ($utf8Bom + [Encoding]::UTF8.GetBytes("q`r`n")) `
        -Actual ([File]::ReadAllBytes((Join-Path $here 'existing.txt'))) `
        -Message 'The file whose encoding is preserved is the one that is written'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative -LikeFilePath, with a different sibling of that name
    # in each folder
    [File]::WriteAllText((Join-Path $here 'like.txt'), "a`r`n", [UTF8Encoding]::new($true))
    [File]::WriteAllText((Join-Path $there 'like.txt'), "a`n")

    # Act
    Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        Write-TextFile -Path .\from-like.txt -Line @('q') -LikeFilePath .\like.txt
    }

    # Assert
    Assert-Equal `
        -Expected ($utf8Bom + [Encoding]::UTF8.GetBytes("q`r`n")) `
        -Actual ([File]::ReadAllBytes((Join-Path $here 'from-like.txt'))) `
        -Message 'A relative -LikeFilePath means the sibling in PowerShell''s location'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a hidden file
    $hiddenPath = Join-Path $sandbox 'hidden.txt'
    [File]::WriteAllText($hiddenPath, "old`r`n", [UTF8Encoding]::new($true))
    (Get-Item -LiteralPath $hiddenPath -Force).Attributes = 'Hidden'

    # Act
    Write-TextFile -Path $hiddenPath -Line @('new')

    # Assert
    $hiddenFlag = (Get-Item -LiteralPath $hiddenPath -Force).Attributes -band [FileAttributes]::Hidden
    Assert-Equal `
        -Expected ($utf8Bom + [Encoding]::UTF8.GetBytes("new`r`n")) `
        -Actual ([File]::ReadAllBytes($hiddenPath)) `
        -Message 'A hidden file is rewritten, keeping its BOM and CRLF'
    Assert-Equal -Expected ([FileAttributes]::Hidden) -Actual $hiddenFlag -Message 'and is still hidden'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an existing file, and text that cannot be encoded
    $keep = Join-Path $sandbox 'keep.txt'
    [File]::WriteAllText($keep, "hand-edited`r`n", [UTF8Encoding]::new($true))
    $keepBytes = [File]::ReadAllBytes($keep)
    $lone = Join-Path $sandbox 'lone.txt'

    # Act / Assert
    Assert-Throws `
        -ScriptBlock { Write-TextFile -Path $keep -Content "a$([char]0xD800)b" } `
        -MessageLike '*translate Unicode character*' `
        -Message 'Text that has no encoding is refused, not written with a stand-in character'
    Assert-Equal `
        -Expected $keepBytes `
        -Actual ([File]::ReadAllBytes($keep)) `
        -Message 'and the file it was meant for is left exactly as it was'
    Assert-Throws `
        -ScriptBlock { Write-TextFile -Path $lone -Content "a$([char]0xD800)b" } `
        -MessageLike '*translate Unicode character*' `
        -Message 'The same text for a new file is refused too'
    Assert-That -Condition (-not (Test-Path -LiteralPath $lone)) -Message 'and leaves no empty file behind'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $ascii = Join-Path $sandbox 'ascii.txt'

    # Act / Assert
    Assert-Throws `
        -ScriptBlock { Write-TextFile -Path $ascii -Content "caf$([char]0xE9)" -Encoding ([Encoding]::ASCII) } `
        -MessageLike '*translate Unicode character*' `
        -Message 'Text the chosen -Encoding cannot hold is refused, not written with a question mark'
    Assert-That -Condition (-not (Test-Path -LiteralPath $ascii)) -Message 'and nothing is written'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an existing Windows-1252 file, which has no mark and is not valid UTF-8
    $legacyBytes = [byte[]](0x63, 0x61, 0x66, 0xE9, 0x0D, 0x0A)
    $legacy = New-TestFile -Directory $sandbox -Name 'legacy.txt' -Byte $legacyBytes
    $fromLegacy = Join-Path $sandbox 'from-legacy.txt'

    # Act / Assert
    Assert-Throws `
        -ScriptBlock { Write-TextFile -Path $legacy -Line @("caf$([char]0xE9)", 'x') } `
        -MessageLike "*legacy.txt'*no byte order mark*not valid UTF-8*", '*pass -Encoding*' `
        -Message 'Writing over a file whose encoding cannot be told is refused, naming the file and the way out'
    Assert-Equal `
        -Expected $legacyBytes `
        -Actual ([File]::ReadAllBytes($legacy)) `
        -Message 'rather than silently turning it into UTF-8'
    Assert-Throws `
        -ScriptBlock { Write-TextFile -Path $fromLegacy -Line @('x') -LikeFilePath $legacy } `
        -MessageLike "*legacy.txt'*no byte order mark*" `
        -Message 'and such a file is no sibling to copy an encoding from either'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the same file, with the encoding it is in
    Write-TextFile -Path $legacy -Line @("caf$([char]0xE9)", 'x') -Encoding ([Encoding]::GetEncoding(28591))

    # Assert
    Assert-Equal `
        -Expected ([byte[]](0x63, 0x61, 0x66, 0xE9, 0x0D, 0x0A, 0x78, 0x0D, 0x0A)) `
        -Actual ([File]::ReadAllBytes($legacy)) `
        -Message '-Encoding writes it as what it is, keeping its CRLF'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a UTF-16 file with a mark but half a character at the end
    $brokenWide = New-TestFile `
        -Directory $sandbox `
        -Name 'broken-wide.txt' `
        -Byte ([byte[]](0xFF, 0xFE, 0x68, 0x00, 0x0A, 0x00, 0x69))

    # Act
    Write-TextFile -Path $brokenWide -Line @('x')

    # Assert
    Assert-Equal `
        -Expected ([byte[]](0xFF, 0xFE, 0x78, 0x00, 0x0A, 0x00)) `
        -Actual ([File]::ReadAllBytes($brokenWide)) `
        -Message 'A file whose mark names its encoding is written in it, even when its old text was damaged'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $noLines = Join-Path $sandbox 'no-lines.txt'

    # Act
    Write-TextFile -Path $noLines -Line @()

    # Assert
    Assert-Equal `
        -Expected ([byte[]]@()) `
        -Actual ([File]::ReadAllBytes($noLines)) `
        -Message 'No lines make an empty file, not one holding a bare line ending'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a CRLF file, and last lines that bring breaks of their own
    $trailing = Join-Path $sandbox 'trailing.txt'
    $doubled = Join-Path $sandbox 'doubled.txt'
    [File]::WriteAllText($trailing, "old`r`n")
    [File]::WriteAllText($doubled, "old`r`n")

    # Act
    Write-TextFile -Path $trailing -Line @('a', "b`n")
    Write-TextFile -Path $doubled -Line @('a', "b`r`n`r`n")

    # Assert
    Assert-Equal `
        -Expected "a`r`nb`r`n" `
        -Actual ([File]::ReadAllText($trailing)) `
        -Message 'A last line that ends with a break of its own still ends the file with just one'
    Assert-Equal `
        -Expected "a`r`nb`r`n`r`n" `
        -Actual ([File]::ReadAllText($doubled)) `
        -Message 'and only one break is taken off it, so a deliberate blank last line stays'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a CRLF file, and a line holding a lone CR
    $loneCr = Join-Path $sandbox 'lone-cr.txt'
    [File]::WriteAllText($loneCr, "old`r`n")

    # Act
    Write-TextFile -Path $loneCr -Line @("x`ry", 'z')

    # Assert
    Assert-Equal `
        -Expected "x`r`ny`r`nz`r`n" `
        -Actual ([File]::ReadAllText($loneCr)) `
        -Message 'A lone CR inside a line becomes the file''s line ending too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file whose lines end in a lone CR
    $crOnly = Join-Path $sandbox 'cr-only.txt'
    [File]::WriteAllText($crOnly, "old`rlines`r")

    # Act
    Write-TextFile -Path $crOnly -Line @('a', 'b')

    # Assert
    Assert-Equal `
        -Expected ('a' + [Environment]::NewLine + 'b' + [Environment]::NewLine) `
        -Actual ([File]::ReadAllText($crOnly)) `
        -Message 'A file ending its lines in a lone CR is rewritten with the platform line ending, never a lone CR'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $positional = Join-Path $sandbox 'positional.txt'

    # Act
    Write-TextFile $positional -Content 'p'

    # Assert
    Assert-Equal `
        -Expected 'p' `
        -Actual ([File]::ReadAllText($positional)) `
        -Message 'The path can be given by position, as with Read-TextFile'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a path on a drive that is not the file system
    Assert-Throws `
        -ScriptBlock {
            Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
                Write-TextFile -Path Env:FILETEXTPROBE -Content 'x'
            }
        } `
        -MessageLike "'Env:FILETEXTPROBE' is not a file system path*" `
        -Message 'A path that is not on the file system is refused'
    Assert-That `
        -Condition (-not (Test-Path -LiteralPath (Join-Path $there 'FILETEXTPROBE'))) `
        -Message 'rather than written as a file in the process''s working directory'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder, and a missing parent folder
    Assert-Throws -ScriptBlock { Write-TextFile -Path $sandbox -Content 'x' } -MessageLike '*is a folder, not a file*' `
        -Message 'A folder says it is a folder'
    Assert-Throws -ScriptBlock { Write-TextFile -Path (Join-Path $sandbox 'nope' 'f.txt') -Content 'x' } `
        -MessageLike '*nope*' `
        -Message 'A missing parent folder names the path that could not be found'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a sibling to copy from that does not exist, and one that is a folder
    $afterMissing = Join-Path $sandbox 'after-missing.txt'
    $folderLike = Join-Path $sandbox 'a-folder'
    New-Item -ItemType Directory -Path $folderLike | Out-Null

    # Act
    Write-TextFile -Path $afterMissing -Content 'x' -LikeFilePath (Join-Path $sandbox 'no-such-sibling.txt')

    # Assert
    Assert-Equal -Expected 'x' -Actual ([File]::ReadAllText($afterMissing)) `
        -Message 'A -LikeFilePath that is not there is ignored, there being nothing to copy'
    Assert-Throws `
        -ScriptBlock { Write-TextFile -Path (Join-Path $sandbox 'after-folder.txt') -Content 'x' -LikeFilePath $folderLike } `
        -MessageLike '*a-folder*is a folder, not a file*' `
        -Message 'but one that is a folder is a mistake, and is refused'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
