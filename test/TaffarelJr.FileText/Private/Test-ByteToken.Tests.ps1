#Requires -Version 7.4
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')
$module = Get-Module TaffarelJr.FileText

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the token written in each encoding, among NULs
    $nul = [byte[]](0x00, 0x01)
    $cases = @(
        @{ Name = 'UTF-8'; Encoding = [UTF8Encoding]::new($false) }
        @{ Name = 'UTF-16 little-endian'; Encoding = [UnicodeEncoding]::new($false, $false) }
        @{ Name = 'UTF-16 big-endian'; Encoding = [UnicodeEncoding]::new($true, $false) }
        @{ Name = 'UTF-32 little-endian'; Encoding = [UTF32Encoding]::new($false, $false) }
        @{ Name = 'UTF-32 big-endian'; Encoding = [UTF32Encoding]::new($true, $false) }
    )

    foreach ($case in $cases) {
        # Act
        $bytes = $nul + $case.Encoding.GetBytes("caf$([char]0xE9) Placeholder") + $nul
        $path = New-TestFile -Directory $sandbox -Name "$([Guid]::NewGuid()).bin" -Byte $bytes
        $found = & $module { param($p) Test-ByteToken -Path $p -Token "caf$([char]0xE9) Placeholder" } $path

        # Assert
        Assert-Equal -Expected $true -Actual $found -Message "A token written in $($case.Name) is found"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $without = New-TestFile `
        -Directory $sandbox `
        -Name 'without.bin' `
        -Byte ($nul + [Encoding]::ASCII.GetBytes('Placeholde') + $nul)
    $empty = New-TestFile -Directory $sandbox -Name 'empty.bin' -Byte ([byte[]]@())

    # Act
    $notFound = & $module { param($p) Test-ByteToken -Path $p -Token 'Placeholder' } $without
    $nothing = & $module { param($p) Test-ByteToken -Path $p -Token 'Placeholder' } $empty

    # Assert
    Assert-Equal -Expected $false -Actual $notFound -Message 'Bytes that only nearly hold the token do not count'
    Assert-Equal -Expected $false -Actual $nothing -Message 'and an empty file holds no token'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - read a few bytes at a time, so the token is split across reads
    $split = New-TestFile `
        -Directory $sandbox `
        -Name 'split.bin' `
        -Byte ($nul + [UTF32Encoding]::new($false, $false).GetBytes('Placeholder') + $nul)

    # Act
    $acrossReads = & $module { param($p) Test-ByteToken -Path $p -Token 'Placeholder' -ChunkSize 5 } $split
    $wholeChunks = & $module { param($p) Test-ByteToken -Path $p -Token 'Placeholder' -ChunkSize 3 } $without

    # Assert
    Assert-Equal -Expected $true -Actual $acrossReads -Message 'A token that spans several reads is still found'
    Assert-Equal `
        -Expected $false `
        -Actual $wholeChunks `
        -Message 'and joining reads does not make up one that is not there'
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
