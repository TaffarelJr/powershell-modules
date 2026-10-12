#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubGistsTestHelper.ps1')

$files = @{
    'mixed.txt' = "a`nb`r`nc é"
    'bom.txt'   = [byte[]](0xEF, 0xBB, 0xBF, 0x78)
    'bomscript.sh' = [byte[]](0xEF, 0xBB, 0xBF, 0x23, 0x21, 0x2F, 0x62, 0x69, 0x6E, 0x2F, 0x73, 0x68, 0x0A)
    'bomtwice.txt' = [byte[]](0xEF, 0xBB, 0xBF, 0xEF, 0xBB, 0xBF, 0x78)
    'bomonly.txt' = [byte[]](0xEF, 0xBB, 0xBF)
    'empty.txt' = ''
    'blank.txt' = "  `r`n`t"
    'cp1252.txt' = [byte[]](0x63, 0x61, 0x66, 0xE9)
    'nul.txt'   = [byte[]](0x61, 0x00, 0x62)
    'u16le.txt' = [byte[]](0x68, 0x00, 0x69, 0x00)
    'u16be.txt' = [byte[]](0x00, 0x68, 0x00, 0x69)
    'u16bom.txt' = [byte[]](0xFF, 0xFE, 0x68, 0x00)
    'zeros.bin' = [byte[]](0x00, 0x00)
    'cjk.txt'   = "€ 漢字"
    'png.bin'   = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
    'zip.bin'   = [byte[]](0x50, 0x4B, 0x03, 0x04, 0x14, 0x00)
    'u16.bin'   = [byte[]](0x01, 0x00, 0x02, 0x00, 0x03, 0x00, 0x04, 0x00)
    'u16cjk.txt' = [Text.Encoding]::Unicode.GetBytes('a日b')
    'u16emoji.txt' = [Text.Encoding]::Unicode.GetBytes("hi 😀")
    'u32be.txt' = [byte[]](0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00, 0x00, 0x68)
    'badu16.bin' = [byte[]](0x41, 0x00, 0x00, 0xD8, 0x41, 0x00, 0x42, 0x00)
    'u16odd.txt' = [byte[]](0x68, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F, 0x00, 0x0A)
}
$folder = New-GistTestFolder -File $files
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $mixed = & $module { param($p) Read-GitHubGistFile -Path $p -Source "'mixed.txt'" } (Join-Path $folder 'mixed.txt')
    $cjk = & $module { param($p) Read-GitHubGistFile -Path $p -Source "'cjk.txt'" } (Join-Path $folder 'cjk.txt')

    # Assert
    Assert-Equal -Expected "a`nb`r`nc é" -Actual $mixed -Message 'A file is read exactly, its line endings as they are'
    Assert-Equal -Expected "€ 漢字" -Actual $cjk -Message 'and characters far beyond ASCII are read as the text they are'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - UTF-8 files that start with a byte-order mark
    $marked = @(
        @{
            Name = 'bom.txt'
            Expected = 'x'
            Message = 'A UTF-8 byte-order mark at the start is dropped, as a gist file has none'
        }
        @{
            Name = 'bomscript.sh'
            Expected = "#!/bin/sh`n"
            Message = 'so a script that Windows PowerShell saved with one starts with #! again'
        }
        @{
            Name = 'bomtwice.txt'
            Expected = "$([char]0xFEFF)x"
            Message = 'and only that first mark is dropped, a second being part of the text'
        }
    )

    # Act / Assert
    foreach ($case in $marked) {
        $path = Join-Path $folder $case.Name
        $actual = & $module { param($p, $n) Read-GitHubGistFile -Path $p -Source "'$n'" } $path $case.Name
        Assert-Equal `
            -Expected @($case.Expected.ToCharArray() | ForEach-Object { [int]$_ }) `
            -Actual @($actual.ToCharArray() | ForEach-Object { [int]$_ }) `
            -Message $case.Message
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - files that cannot be a gist file
    $refused = @(
        @{
            Name = 'empty.txt'
            Like = "-AddFile 'empty.txt' is empty or only whitespace, and GitHub refuses a gist file with no content."
            Message = 'An empty file is refused, named as the caller gave it'
        }
        @{
            Name = 'blank.txt'
            Like = "-AddFile 'blank.txt' is empty or only whitespace, and GitHub refuses a gist file with no content."
            Message = 'and so is one of whitespace alone'
        }
        @{
            Name = 'bomonly.txt'
            Like = "-AddFile 'bomonly.txt' is empty or only whitespace, and GitHub refuses a gist file with no content."
            Message = 'and so is one that holds only a byte-order mark, which is dropped'
        }
        @{
            Name = 'cp1252.txt'
            Like = "-AddFile 'cp1252.txt' is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first."
            Message = 'A file that is not UTF-8 is refused'
        }
        @{
            Name = 'u16le.txt'
            Like = "-AddFile 'u16le.txt' is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first."
            Message = 'and so is UTF-16 text without a byte-order mark, told as an encoding rather than as binary data'
        }
        @{
            Name = 'u16be.txt'
            Like = "-AddFile 'u16be.txt' is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first."
            Message = 'big-endian too'
        }
        @{
            Name = 'u16bom.txt'
            Like = "-AddFile 'u16bom.txt' is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first."
            Message = 'and UTF-16 with its byte-order mark'
        }
        @{
            Name = 'zeros.bin'
            Like = "-AddFile 'zeros.bin' holds binary data, and a gist holds text only."
            Message = 'while NULs alone are binary data, not UTF-16'
        }
        @{
            Name = 'nul.txt'
            Like = "-AddFile 'nul.txt' holds binary data, and a gist holds text only."
            Message = 'A binary file is refused'
        }
        @{
            Name = 'png.bin'
            Like = "-AddFile 'png.bin' holds binary data, and a gist holds text only."
            Message = 'and so is an image, told as binary rather than as an encoding'
        }
        @{
            Name = 'zip.bin'
            Like = "-AddFile 'zip.bin' holds binary data, and a gist holds text only."
            Message = 'and an archive'
        }
        @{
            Name = 'u16.bin'
            Like = "-AddFile 'u16.bin' holds binary data, and a gist holds text only."
            Message = 'and 16-bit data whose characters would be control characters'
        }
        @{
            Name = 'u16cjk.txt'
            Like = "-AddFile 'u16cjk.txt' is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first."
            Message = 'while UTF-16 mixing ASCII with characters beyond Latin-1 is told as an encoding'
        }
        @{
            Name = 'u16emoji.txt'
            Like = "-AddFile 'u16emoji.txt' is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first."
            Message = 'and so is UTF-16 holding an emoji, whose surrogate holds a NUL of the other parity'
        }
        @{
            Name = 'u32be.txt'
            Like = "-AddFile 'u32be.txt' is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first."
            Message = 'and UTF-32 with its big-endian byte-order mark'
        }
        @{
            Name = 'badu16.bin'
            Like = "-AddFile 'badu16.bin' holds binary data, and a gist holds text only."
            Message = 'while NULs on one side that do not read as UTF-16, a lone surrogate among them, are binary data'
        }
        @{
            Name = 'u16odd.txt'
            Like = "-AddFile 'u16odd.txt' holds binary data, and a gist holds text only."
            Message = 'and UTF-16 with a stray last byte is no longer UTF-16, so binary'
        }
    )

    # Act / Assert
    foreach ($case in $refused) {
        Assert-Throws -ScriptBlock {
            & $module { param($p, $s) Read-GitHubGistFile -Path $p -Source $s } (Join-Path $folder $case.Name) "-AddFile '$($case.Name)'"
        } -MessageLike $case.Like -Message $case.Message
    }
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
