#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    # Arrange - a CRLF, UTF-8-BOM file containing the token
    $path = Join-Path $tempDir 'file.txt'
    [System.IO.File]::WriteAllText($path, "Hello Placeholder`r`n", [System.Text.UTF8Encoding]::new($true))

    # Act
    $result = Update-FileToken -Path $path -From 'Placeholder' -To 'Real'

    # Assert
    Assert-That -Condition $result -Message 'A file containing the token reports it was rewritten'
    Assert-Equal -Expected "Hello Real`r`n" -Actual ([System.IO.File]::ReadAllText($path)) -Message 'The token is replaced in the content'
    $bytes = [System.IO.File]::ReadAllBytes($path)
    Assert-That -Condition ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) -Message 'The BOM survives the rewrite'

    # Arrange / Act - a file without the token is left untouched and reports no rewrite
    $untouchedPath = Join-Path $tempDir 'untouched.txt'
    [System.IO.File]::WriteAllText($untouchedPath, 'nothing to see here')
    $result = Update-FileToken -Path $untouchedPath -From 'Placeholder' -To 'Real'

    # Assert
    Assert-That -Condition (-not $result) -Message 'A file without the token reports it was not rewritten'
    Assert-Equal -Expected 'nothing to see here' -Actual ([System.IO.File]::ReadAllText($untouchedPath)) -Message 'A file without the token is left completely untouched'

    # Arrange / Act - a binary file (contains a NUL)
    # holding the token is declined, not corrupted
    $binaryPath = Join-Path $tempDir 'binary.dat'
    [System.IO.File]::WriteAllBytes($binaryPath, [byte[]](0x50, 0x6C, 0x61, 0x63, 0x65, 0x68, 0x6F, 0x6C, 0x64, 0x65, 0x72, 0x00, 0xFF))
    $originalBytes = [System.IO.File]::ReadAllBytes($binaryPath)
    $result = Update-FileToken -Path $binaryPath -From 'Placeholder' -To 'Real'

    # Assert
    Assert-That -Condition (-not $result) -Message 'Binary content holding the token reports it was not rewritten'
    Assert-Equal -Expected $originalBytes -Actual ([System.IO.File]::ReadAllBytes($binaryPath)) -Message 'Binary content is left byte-for-byte untouched'
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
