#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force

$path = Join-Path ([System.IO.Path]::GetTempPath()) "$([guid]::NewGuid()).txt"
try {
    # Arrange - a UTF-8-with-BOM, CRLF file
    [System.IO.File]::WriteAllText($path, "line one`r`nline two`r`n", [System.Text.UTF8Encoding]::new($true))

    # Act
    $file = Read-TextFile -Path $path

    # Assert
    Assert-Equal -Expected "line one`r`nline two`r`n" -Actual $file.Content -Message 'Content comes back BOM-stripped, as plain text'
    Assert-Equal -Expected 3 -Actual $file.Encoding.GetPreamble().Length -Message 'Encoding still reports the BOM the file actually has'
    Assert-Equal -Expected "`r`n" -Actual $file.LineEnding -Message 'LineEnding reflects what the content actually uses'
}
finally {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
