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
    # Arrange - file starts, and whether they look binary
    $cases = @(
        @{
            Name     = 'text with no NUL'
            Bytes    = [Encoding]::ASCII.GetBytes('plain text')
            Expected = $false
        }
        @{
            Name     = 'a NUL in the first bytes'
            Bytes    = [byte[]](0x50, 0x4B, 0x00, 0x01)
            Expected = $true
        }
        @{
            Name     = 'a NUL at the last byte of the first 8 KB'
            Bytes    = [Encoding]::ASCII.GetBytes('a' * 8191) + [byte[]](0x00)
            Expected = $true
        }
        @{
            Name     = 'a NUL just past the first 8 KB'
            Bytes    = [Encoding]::ASCII.GetBytes('a' * 8192) + [byte[]](0x00)
            Expected = $false
        }
        @{
            Name     = 'UTF-16 text with its mark'
            Bytes    = [byte[]](0xFF, 0xFE) + [UnicodeEncoding]::new($false, $false).GetBytes('text')
            Expected = $false
        }
        @{
            Name     = 'UTF-32 text with its mark'
            Bytes    = [byte[]](0x00, 0x00, 0xFE, 0xFF) + [UTF32Encoding]::new($true, $false).GetBytes('text')
            Expected = $false
        }
        @{
            Name     = 'UTF-16 text without a mark'
            Bytes    = [UnicodeEncoding]::new($false, $false).GetBytes('text')
            Expected = $true
        }
        @{
            Name     = 'a UTF-8 mark and a NUL'
            Bytes    = [byte[]](0xEF, 0xBB, 0xBF, 0x61, 0x00)
            Expected = $true
        }
        @{
            Name     = 'no bytes'
            Bytes    = [byte[]]@()
            Expected = $false
        }
    )

    foreach ($case in $cases) {
        # Act
        $path = New-TestFile -Directory $sandbox -Name "$([Guid]::NewGuid()).bin" -Byte $case.Bytes
        $binary = & $module { param($p) Test-BinaryHead -Path $p } $path

        # Assert
        Assert-Equal -Expected $case.Expected -Actual $binary -Message "$($case.Name): binary is $($case.Expected)"
    }
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
