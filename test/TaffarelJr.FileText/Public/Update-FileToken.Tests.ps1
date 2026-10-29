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
    # Arrange - a CRLF, UTF-8-BOM file containing the token
    $path = Join-Path $sandbox 'file.txt'
    [File]::WriteAllText($path, "Hello Placeholder`r`n", [UTF8Encoding]::new($true))

    # Act
    $result = Update-FileToken -Path $path -From 'Placeholder' -To 'Real'

    # Assert
    Assert-That -Condition $result -Message 'A file containing the token reports it was rewritten'
    Assert-Equal -Expected ([byte[]](0xEF, 0xBB, 0xBF) + [Encoding]::UTF8.GetBytes("Hello Real`r`n")) `
        -Actual ([File]::ReadAllBytes($path)) `
        -Message 'The token is replaced, and the BOM and CRLF survive'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file without the token
    $untouched = Join-Path $sandbox 'untouched.txt'
    [File]::WriteAllText($untouched, 'nothing to see here')

    # Act
    $result = Update-FileToken -Path $untouched -From 'Placeholder' -To 'Real'

    # Assert
    Assert-That -Condition (-not $result) -Message 'A file without the token reports it was not rewritten'
    Assert-Equal -Expected 'nothing to see here' -Actual ([File]::ReadAllText($untouched)) `
        -Message 'and is left completely untouched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file with the token, replaced by the same text
    $same = Join-Path $sandbox 'same.txt'
    [File]::WriteAllText($same, 'Placeholder')
    $stamp = [DateTime]::new(2020, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
    (Get-Item -LiteralPath $same).LastWriteTimeUtc = $stamp

    # Act
    $result = Update-FileToken -Path $same -From 'Placeholder' -To 'Placeholder'

    # Assert
    Assert-That -Condition (-not $result) -Message 'Replacing a token with itself reports it was not rewritten'
    Assert-Equal -Expected $stamp -Actual (Get-Item -LiteralPath $same).LastWriteTimeUtc `
        -Message 'and the file is not written to at all'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a binary file (it holds a NUL) that also holds the token
    $binary = New-TestFile -Directory $sandbox -Name 'binary.dat' `
        -Byte ([byte[]](0x50, 0x6C, 0x61, 0x63, 0x65, 0x68, 0x6F, 0x6C, 0x64, 0x65, 0x72, 0x00, 0xFF))
    $original = [File]::ReadAllBytes($binary)

    # Act
    $warnings = @(Get-WarningOutput -ScriptBlock {
            $script:binaryResult = Update-FileToken -Path $binary -From 'Placeholder' -To 'Real'
        })

    # Assert
    Assert-That -Condition (-not $binaryResult) -Message 'Binary content holding the token reports it was not rewritten'
    Assert-Equal -Expected $original -Actual ([File]::ReadAllBytes($binary)) `
        -Message 'and is left byte-for-byte untouched'
    Assert-Equal `
        -Expected @("Skipped binary content: '$binary' holds 'Placeholder' and a NUL, so it was not rewritten.") `
        -Actual $warnings `
        -Message 'and says so, so declining it is not mistaken for there being nothing to do'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - UTF-16 text holding the token, with no mark to say it is UTF-16
    $bare16 = New-TestFile `
        -Directory $sandbox `
        -Name 'bare16.txt' `
        -Byte ([UnicodeEncoding]::new($false, $false).GetBytes("Placeholder`r`n"))
    $bare16Before = [File]::ReadAllBytes($bare16)

    # Act
    $bare16Warnings = @(Get-WarningOutput -ScriptBlock {
            $script:bare16Result = Update-FileToken -Path $bare16 -From 'Placeholder' -To 'Real'
        })

    # Assert
    Assert-That -Condition (-not $bare16Result) -Message 'UTF-16 without a mark is not rewritten as if it were UTF-8'
    Assert-Equal -Expected $bare16Before -Actual ([File]::ReadAllBytes($bare16)) -Message 'and is left as it was'
    Assert-Equal `
        -Expected @("Skipped binary content: '$bare16' holds 'Placeholder' and a NUL, so it was not rewritten.") `
        -Actual $bare16Warnings `
        -Message 'but the token in it is found and reported, not passed over in silence'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a hidden file with the token
    $hidden = Join-Path $sandbox 'hidden.txt'
    [File]::WriteAllText($hidden, "Placeholder`r`n", [UTF8Encoding]::new($true))
    (Get-Item -LiteralPath $hidden -Force).Attributes = 'Hidden'

    # Act
    $hiddenResult = Update-FileToken -Path $hidden -From 'Placeholder' -To 'Real'

    # Assert
    Assert-That -Condition $hiddenResult -Message 'A hidden file is rewritten'
    Assert-Equal `
        -Expected ([byte[]](0xEF, 0xBB, 0xBF) + [Encoding]::UTF8.GetBytes("Real`r`n")) `
        -Actual ([File]::ReadAllBytes($hidden)) `
        -Message 'with the token replaced and its BOM and CRLF kept'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - files listed by Get-ChildItem
    $piped = Join-Path $sandbox 'piped'
    New-Item -ItemType Directory -Path $piped | Out-Null
    [File]::WriteAllText((Join-Path $piped 'a.txt'), 'Placeholder a')
    [File]::WriteAllText((Join-Path $piped 'b.txt'), 'b')
    $listed = @(Get-ChildItem -LiteralPath $piped -File | Sort-Object Name)

    # Act
    $pipedResult = @($listed | Update-FileToken -From 'Placeholder' -To 'Real')

    # Assert
    Assert-Equal `
        -Expected @($true, $false) `
        -Actual $pipedResult `
        -Message 'Files piped in are each updated, with one answer per file'
    Assert-Equal `
        -Expected 'Real a' `
        -Actual ([File]::ReadAllText((Join-Path $piped 'a.txt'))) `
        -Message 'and the one with the token is rewritten'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - path strings, a Get-Content list, and Resolve-Path output
    $byText = Join-Path $sandbox 'by-text'
    New-Item -ItemType Directory -Path $byText | Out-Null
    $stringFile = Join-Path $byText 'string.txt'
    $listedFile = Join-Path $byText 'listed.txt'
    $resolvedFile = Join-Path $byText 'resolved.txt'
    [File]::WriteAllText($stringFile, 'Placeholder')
    [File]::WriteAllText($listedFile, 'Placeholder')
    [File]::WriteAllText($resolvedFile, 'Placeholder')
    $list = Join-Path $sandbox 'list.txt'
    Set-Content -LiteralPath $list -Value $listedFile

    # Act
    $fromString = @($stringFile | Update-FileToken -From 'Placeholder' -To 'Real')
    $fromList = @(Get-Content -LiteralPath $list | Update-FileToken -From 'Placeholder' -To 'Real')
    $fromResolved = @(Resolve-Path -LiteralPath $resolvedFile | Update-FileToken -From 'Placeholder' -To 'Real')
    $contents = @($stringFile, $listedFile, $resolvedFile | ForEach-Object { [File]::ReadAllText($_) })

    # Assert
    Assert-Equal -Expected @($true) -Actual $fromString -Message 'A path string piped in is updated'
    Assert-Equal -Expected @($true) -Actual $fromList -Message 'and so is a line of a file list'
    Assert-Equal -Expected @($true) -Actual $fromResolved -Message 'and Resolve-Path output, by its Path'
    Assert-Equal -Expected @('Real', 'Real', 'Real') -Actual $contents -Message 'and each of those files is rewritten'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder listed before a file
    $mixedListing = Join-Path $sandbox 'mixed-listing'
    New-Item -ItemType Directory -Path (Join-Path $mixedListing 'a-folder') -Force | Out-Null
    [File]::WriteAllText((Join-Path $mixedListing 'b.txt'), 'Placeholder')
    $entries = @(Get-ChildItem -LiteralPath $mixedListing | Sort-Object Name)

    # Act
    $folderFirst = { $entries | Update-FileToken -From 'Placeholder' -To 'Real' }

    # Assert
    Assert-Throws -ScriptBlock $folderFirst -MessageLike '*a-folder*is a folder, not a file*' `
        -Message 'A folder in the pipeline stops it, naming the folder'
    Assert-Equal -Expected 'Placeholder' -Actual ([File]::ReadAllText((Join-Path $mixedListing 'b.txt'))) `
        -Message 'so a file after it is not reached'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a token to be removed
    $removal = Join-Path $sandbox 'removal.txt'
    [File]::WriteAllText($removal, 'keep REMOVEME this')

    # Act
    $result = Update-FileToken -Path $removal -From 'REMOVEME' -To ''

    # Assert
    Assert-That -Condition $result -Message 'An empty replacement is allowed'
    Assert-Equal -Expected 'keep  this' -Actual ([File]::ReadAllText($removal)) -Message 'and removes the token'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - every occurrence, and only the exact case
    $many = Join-Path $sandbox 'many.txt'
    [File]::WriteAllText($many, 'Placeholder placeholder Placeholder')

    # Act
    $null = Update-FileToken -Path $many -From 'Placeholder' -To 'X'

    # Assert
    Assert-Equal -Expected 'X placeholder X' -Actual ([File]::ReadAllText($many)) `
        -Message 'Every occurrence is replaced, and only those with the same case'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file whose line endings are mixed
    $mixed = Join-Path $sandbox 'mixed.txt'
    [File]::WriteAllText($mixed, "a Placeholder`nb`r`nc`n")

    # Act
    $null = Update-FileToken -Path $mixed -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected "a Real`nb`r`nc`n" -Actual ([File]::ReadAllText($mixed)) `
        -Message 'Only the token changes - every line ending stays as it was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - UTF-16 and UTF-32 files with the token
    $utf16 = Join-Path $sandbox 'utf16.txt'
    $utf32 = Join-Path $sandbox 'utf32.txt'
    [File]::WriteAllText($utf16, "Placeholder`r`n", [UnicodeEncoding]::new($false, $true))
    [File]::WriteAllText($utf32, "Placeholder`r`n", [UTF32Encoding]::new($false, $true))

    # Act
    $null = Update-FileToken -Path $utf16 -From 'Placeholder' -To 'Real'
    $null = Update-FileToken -Path $utf32 -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected ([byte[]](0xFF, 0xFE) + [UnicodeEncoding]::new($false, $false).GetBytes("Real`r`n")) `
        -Actual ([File]::ReadAllBytes($utf16)) `
        -Message 'A UTF-16 file is rewritten as UTF-16, not as UTF-8 text'
    Assert-Equal `
        -Expected ([byte[]](0xFF, 0xFE, 0x00, 0x00) + [UTF32Encoding]::new($false, $false).GetBytes("Real`r`n")) `
        -Actual ([File]::ReadAllBytes($utf32)) `
        -Message 'and a UTF-32 file as UTF-32'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - Windows-1252 text that holds the token, and some that does not
    $withToken = New-TestFile -Directory $sandbox -Name 'cp1252-with.txt' `
        -Byte ([Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9) Placeholder"))
    $without = New-TestFile -Directory $sandbox -Name 'cp1252-without.txt' `
        -Byte ([Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9)"))
    $withBytes = [File]::ReadAllBytes($withToken)
    $withoutBytes = [File]::ReadAllBytes($without)

    # Act
    $declined = Update-FileToken -Path $without -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Throws -ScriptBlock { Update-FileToken -Path $withToken -From 'Placeholder' -To 'Real' } `
        -MessageLike '*cp1252-with.txt*is not valid utf-8 text*' `
        -Message 'Text with the token that is not valid UTF-8 is refused, naming the file'
    Assert-Equal -Expected $withBytes -Actual ([File]::ReadAllBytes($withToken)) `
        -Message 'and is left exactly as it was, not rewritten with replacement characters'
    Assert-That -Condition (-not $declined) -Message 'A file like it without the token is simply not rewritten'
    Assert-Equal -Expected $withoutBytes -Actual ([File]::ReadAllBytes($without)) `
        -Message 'and is not an error, since there is nothing to do to it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - PowerShell is in one folder and the process in another
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null
    [File]::WriteAllText((Join-Path $here 'f.txt'), 'Placeholder')
    [File]::WriteAllText((Join-Path $there 'f.txt'), 'Placeholder')

    # Act
    $null = Use-SplitLocation -Location $here -ProcessDirectory $there `
        -ScriptBlock { Update-FileToken -Path .\f.txt -From 'Placeholder' -To 'Real' }

    # Assert
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText((Join-Path $here 'f.txt'))) `
        -Message 'A relative path updates the file in PowerShell''s location'
    Assert-Equal -Expected 'Placeholder' -Actual ([File]::ReadAllText((Join-Path $there 'f.txt'))) `
        -Message 'and leaves the one in the process''s working directory alone'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an object that carries only a PSPath, as an item of the file system provider does
    $pipedFile = Join-Path $sandbox 'pspath.txt'
    [File]::WriteAllText($pipedFile, 'Placeholder')
    $psPathOnly = [PSCustomObject]@{ PSPath = "Microsoft.PowerShell.Core\FileSystem::$pipedFile" }

    # Act
    $byPsPath = $psPathOnly | Update-FileToken -From 'Placeholder' -To 'Real'

    # Assert
    Assert-That -Condition $byPsPath -Message 'An object with only a PSPath is updated by it'
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText($pipedFile)) `
        -Message 'as a provider-qualified path'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a file that is not there, and a blank token
    Assert-Throws -ScriptBlock { Update-FileToken -Path (Join-Path $sandbox 'nope.txt') -From 'a' -To 'b' } `
        -MessageLike "No such file: '*nope.txt'*" `
        -Message 'A missing file says so, naming it'
    Assert-Throws -ScriptBlock { Update-FileToken -Path $path -From ' ' -To 'b' } -MessageLike '*From*' `
        -Message 'A blank token to look for is refused'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
