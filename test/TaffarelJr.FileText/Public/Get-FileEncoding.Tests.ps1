#Requires -Version 7.0
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force

function New-TestFile([byte[]]$Bytes) {
    $path = Join-Path ([Path]::GetTempPath()) "$([Guid]::NewGuid()).txt"
    [File]::WriteAllBytes($path, $Bytes)
    return $path
}

$paths = [System.Collections.Generic.List[string]]::new()
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - no mark at all decodes as UTF-8 without a BOM
    $path = New-TestFile -Bytes ([byte[]](0x68, 0x69))
    $paths.Add($path)
    $encoding = Get-FileEncoding -Path $path
    Assert-That -Condition ($encoding -is [System.Text.UTF8Encoding]) -Message 'No mark decodes as UTF-8'
    Assert-Equal -Expected 0 -Actual $encoding.GetPreamble().Length -Message 'No mark means no BOM is written back'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - a UTF-8 BOM is recognized
    $path = New-TestFile -Bytes ([byte[]](0xEF, 0xBB, 0xBF, 0x68, 0x69))
    $paths.Add($path)
    $encoding = Get-FileEncoding -Path $path
    Assert-Equal -Expected 3 -Actual $encoding.GetPreamble().Length -Message 'A UTF-8 BOM round-trips as a 3-byte preamble'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - a UTF-16 LE BOM is recognized
    $path = New-TestFile -Bytes ([byte[]](0xFF, 0xFE, 0x68, 0x00, 0x69, 0x00))
    $paths.Add($path)
    $encoding = Get-FileEncoding -Path $path
    Assert-That -Condition ($encoding -is [UnicodeEncoding]) -Message 'A UTF-16 LE BOM decodes as Unicode'
    Assert-Equal -Expected ([byte[]](0xFF, 0xFE)) -Actual $encoding.GetPreamble() -Message 'The preamble is little-endian'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - a UTF-16 BE BOM is recognized
    $path = New-TestFile -Bytes ([byte[]](0xFE, 0xFF, 0x00, 0x68, 0x00, 0x69))
    $paths.Add($path)
    $encoding = Get-FileEncoding -Path $path
    Assert-Equal -Expected ([byte[]](0xFE, 0xFF)) -Actual $encoding.GetPreamble() -Message 'The preamble is big-endian'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - an empty file has no BOM
    $path = New-TestFile -Bytes ([byte[]]@())
    $paths.Add($path)
    $encoding = Get-FileEncoding -Path $path
    Assert-Equal -Expected 0 -Actual $encoding.GetPreamble().Length -Message 'An empty file has no BOM'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - a file shorter than any BOM does not overrun or crash
    $path = New-TestFile -Bytes ([byte[]](0x61, 0x62))
    $paths.Add($path)
    $encoding = Get-FileEncoding -Path $path
    Assert-Equal -Expected 0 -Actual $encoding.GetPreamble().Length -Message 'A file shorter than any BOM is read safely and reports no BOM'
}
finally {
    $paths | ForEach-Object { Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue }
}

exit (Complete-TestRun)
