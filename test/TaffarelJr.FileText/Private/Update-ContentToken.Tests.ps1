#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.FileText/Public/Get-FileEncoding.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.FileText/Public/Get-LineEnding.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.FileText/Public/Read-TextFile.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.FileText/Public/Write-TextFile.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.FileText/Public/Update-FileToken.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.FileText/Private/Update-ContentToken.ps1')

$tempDir = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - one file with the token, one without, one binary with the token
    $withToken = Join-Path $tempDir 'with-token.txt'
    [File]::WriteAllText($withToken, 'Placeholder')
    $withoutToken = Join-Path $tempDir 'without-token.txt'
    [File]::WriteAllText($withoutToken, 'nothing here')
    $binaryWithToken = Join-Path $tempDir 'binary.dat'
    [File]::WriteAllBytes($binaryWithToken, [byte[]](0x50, 0x6C, 0x61, 0x63, 0x65, 0x68, 0x6F, 0x6C, 0x64, 0x65, 0x72, 0x00))

    $items = @(Get-ChildItem -LiteralPath $tempDir -File)

    # Act
    $result = Update-ContentToken -Item $items -From 'Placeholder' -To 'Real' -SkipExtension @()

    # Assert
    Assert-Equal -Expected 1 -Actual $result.Edited -Message 'Only the file genuinely containing the token is edited'
    Assert-Equal -Expected 'Real' -Actual ([File]::ReadAllText($withToken)) -Message 'The edited file has the token replaced'
    Assert-Equal -Expected 'nothing here' -Actual ([File]::ReadAllText($withoutToken)) -Message 'A file without the token is left alone'
    Assert-Equal -Expected 1 -Actual $result.Warning.Count -Message 'The binary file is reported as a warning'
    Assert-That -Condition ($result.Warning[0] -like '*binary*') -Message 'The warning says why the file was skipped'
    Assert-Equal -Expected 0 -Actual $result.Failed.Count -Message 'Nothing here counts as an unrecoverable failure'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a skip-extension file is excluded from the content pass entirely
    $skipPath = Join-Path $tempDir 'image.png'
    [File]::WriteAllText($skipPath, 'Placeholder')
    $items2 = @(Get-ChildItem -LiteralPath $tempDir -File)
    $result2 = Update-ContentToken -Item $items2 -From 'Placeholder' -To 'Real' -SkipExtension @('.png')

    # Assert
    Assert-Equal -Expected 0 -Actual $result2.Edited -Message 'A skip-extension file is excluded before it is even read'
    Assert-Equal -Expected 'Placeholder' -Actual ([File]::ReadAllText($skipPath)) -Message 'Its content is left completely untouched'
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
