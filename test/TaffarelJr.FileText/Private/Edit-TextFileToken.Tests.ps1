#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')
$module = Get-Module TaffarelJr.FileText

function Invoke-EditTextFileToken {
    <#
    .SYNOPSIS
        Calls the private Edit-TextFileToken with a -Cmdlet that does not
        support ShouldProcess, so it always answers yes, as for a public
        caller run without -WhatIf.
    #>
    [CmdletBinding()]
    param(
        [string]$Path,

        [string]$From,

        [AllowEmptyString()]
        [string]$To
    )

    & $module {
        [CmdletBinding()]
        param($p, $f, $t)
        Edit-TextFileToken -Path $p -From $f -To $t -Cmdlet $PSCmdlet
    } $Path $From $To
}

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file with the token, a BOM, and mixed line endings
    $edited = Join-Path $sandbox 'edited.txt'
    [File]::WriteAllText($edited, "Placeholder`nb`r`nPlaceholder", [UTF8Encoding]::new($true))

    # Act
    $status = Invoke-EditTextFileToken -Path $edited -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 'Edited' -Actual $status -Message 'A file with the token is Edited'
    Assert-Equal -Expected ([byte[]](0xEF, 0xBB, 0xBF) + [Encoding]::UTF8.GetBytes("Real`nb`r`nReal")) `
        -Actual ([File]::ReadAllBytes($edited)) `
        -Message 'with every occurrence replaced, and the mark and every line ending as they were'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file without the token
    $quiet = Join-Path $sandbox 'quiet.txt'
    [File]::WriteAllText($quiet, 'nothing here')
    $quietBefore = (Get-Item -LiteralPath $quiet).LastWriteTimeUtc
    Start-Sleep -Milliseconds 50

    # Act
    $none = Invoke-EditTextFileToken -Path $quiet -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 'NoToken' -Actual $none -Message 'A file without the token is NoToken'
    Assert-Equal -Expected $quietBefore -Actual (Get-Item -LiteralPath $quiet).LastWriteTimeUtc `
        -Message 'and is not written to at all'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file that has the token and a NUL
    $binary = New-TestFile -Directory $sandbox -Name 'binary.dat' `
        -Byte ([byte[]](0x50, 0x6C, 0x61, 0x63, 0x65, 0x68, 0x6F, 0x6C, 0x64, 0x65, 0x72, 0x00))
    $binaryBefore = [File]::ReadAllBytes($binary)

    # Act
    $binaryStatus = Invoke-EditTextFileToken -Path $binary -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 'Binary' -Actual $binaryStatus -Message 'Content holding a NUL is Binary'
    Assert-Equal -Expected $binaryBefore -Actual ([File]::ReadAllBytes($binary)) -Message 'and is left untouched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a binary file that has no token
    $binaryWithout = New-TestFile -Directory $sandbox -Name 'binary-without.dat' -Byte ([byte[]](0x01, 0x00, 0x02))

    # Act
    $binaryNone = Invoke-EditTextFileToken -Path $binaryWithout -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 'NoToken' -Actual $binaryNone `
        -Message 'Binary content with no token is NoToken, not Binary - there is nothing to decline'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - Windows-1252 text with and without the token
    $latinWith = New-TestFile -Directory $sandbox -Name 'with.txt' `
        -Byte ([Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9) Placeholder"))
    $latinWithout = New-TestFile -Directory $sandbox -Name 'without.txt' `
        -Byte ([Encoding]::GetEncoding(28591).GetBytes("caf$([char]0xE9)"))
    $withBefore = [File]::ReadAllBytes($latinWith)

    # Act
    $latinStatus = Invoke-EditTextFileToken -Path $latinWithout -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Throws `
        -ScriptBlock { Invoke-EditTextFileToken -Path $latinWith -From 'Placeholder' -To 'Real' } `
        -MessageLike '*with.txt*is not valid utf-8 text*' `
        -Message 'Text with the token that would not survive a rewrite throws, saying why'
    Assert-Equal -Expected $withBefore -Actual ([File]::ReadAllBytes($latinWith)) -Message 'and is left as it was'
    Assert-Equal -Expected 'NoToken' -Actual $latinStatus `
        -Message 'The same kind of text without the token is just NoToken'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a token to remove
    $removal = Join-Path $sandbox 'removal.txt'
    [File]::WriteAllText($removal, 'a REMOVEME b')

    # Act
    $null = Invoke-EditTextFileToken -Path $removal -From 'REMOVEME' -To ''

    # Assert
    Assert-Equal -Expected 'a  b' -Actual ([File]::ReadAllText($removal)) `
        -Message 'An empty replacement removes the token'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the file is in PowerShell's location, not the process's
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null
    [File]::WriteAllText((Join-Path $here 'f.txt'), 'Placeholder')

    # Act
    $relative = Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        Invoke-EditTextFileToken -Path '.\f.txt' -From 'Placeholder' -To 'Real'
    }

    # Assert
    Assert-Equal -Expected 'Edited' -Actual $relative -Message 'A relative path is found in PowerShell''s location'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a file that is not there, and a folder
    Assert-Throws `
        -ScriptBlock { Invoke-EditTextFileToken -Path (Join-Path $sandbox 'nope.txt') -From 'a' -To 'b' } `
        -MessageLike "No such file: '*nope.txt'." `
        -Message 'A missing file says so'
    Assert-Throws -ScriptBlock { Invoke-EditTextFileToken -Path $sandbox -From 'a' -To 'b' } `
        -MessageLike '*is a folder, not a file.' `
        -Message 'A folder says it is a folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - text with the token whose only NUL comes after the first 8 KB
    $lateBytes = [Encoding]::ASCII.GetBytes(('a' * 9000) + 'Placeholder') + [byte[]](0x00)
    $late = New-TestFile -Directory $sandbox -Name 'late-nul.txt' -Byte $lateBytes

    # Act
    $lateStatus = Invoke-EditTextFileToken -Path $late -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal -Expected 'Binary' -Actual $lateStatus -Message 'A NUL past the first 8 KB still makes the file Binary'
    Assert-Equal -Expected $lateBytes -Actual ([File]::ReadAllBytes($late)) -Message 'and it is left as it was'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the token in UTF-16 and UTF-32 without a mark
    $bare16 = New-TestFile `
        -Directory $sandbox `
        -Name 'bare16.txt' `
        -Byte ([UnicodeEncoding]::new($true, $false).GetBytes('Placeholder'))
    $bare32 = New-TestFile `
        -Directory $sandbox `
        -Name 'bare32.txt' `
        -Byte ([UTF32Encoding]::new($false, $false).GetBytes('Placeholder'))

    # Act
    $bare16Status = Invoke-EditTextFileToken -Path $bare16 -From 'Placeholder' -To 'Real'
    $bare32Status = Invoke-EditTextFileToken -Path $bare32 -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal `
        -Expected 'Binary' `
        -Actual $bare16Status `
        -Message 'UTF-16 holding the token with no mark is Binary, not NoToken'
    Assert-Equal -Expected 'Binary' -Actual $bare32Status -Message 'and so is UTF-32'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - large files that start with a NUL, one with the token at the
    # very end and one without, and a decoder that fails if it is called
    $bigBytes = [byte[]]::new(3MB)
    $bigWithout = New-TestFile -Directory $sandbox -Name 'big-without.bin' -Byte $bigBytes
    [Encoding]::ASCII.GetBytes('Placeholder').CopyTo($bigBytes, $bigBytes.Length - 11)
    $bigWith = New-TestFile -Directory $sandbox -Name 'big-with.bin' -Byte $bigBytes
    & $module {
        function script:Read-DecodedText {
            throw 'binary content was decoded'
        }
    }

    # Act
    $bigWithStatus = Invoke-EditTextFileToken -Path $bigWith -From 'Placeholder' -To 'Real'
    $bigWithoutStatus = Invoke-EditTextFileToken -Path $bigWithout -From 'Placeholder' -To 'Real'

    # Assert
    Assert-Equal `
        -Expected 'Binary' `
        -Actual $bigWithStatus `
        -Message 'Binary content is found to hold the token without being decoded'
    Assert-Equal -Expected 'NoToken' -Actual $bigWithoutStatus -Message 'and found not to, likewise'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
