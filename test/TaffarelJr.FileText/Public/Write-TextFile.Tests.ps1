#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force

function Test-HasBom([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    # Arrange / Act - a brand new file with no reference
    # gets UTF-8 no-BOM and the platform EOL
    $newPath = Join-Path $tempDir 'new.txt'
    Write-TextFile -Path $newPath -Lines @('a', 'b')

    # Assert
    Assert-That -Condition (-not (Test-HasBom $newPath)) -Message 'A brand new file with no reference has no BOM'
    Assert-Equal -Expected ('a' + [Environment]::NewLine + 'b' + [Environment]::NewLine) -Actual ([System.IO.File]::ReadAllText($newPath)) -Message '-Lines is joined with exactly one trailing line ending'

    # Arrange - an existing CRLF, UTF-8-BOM file
    $existingPath = Join-Path $tempDir 'existing.txt'
    [System.IO.File]::WriteAllText($existingPath, "old content`r`n", [System.Text.UTF8Encoding]::new($true))

    # Act - overwrite it with -Lines
    Write-TextFile -Path $existingPath -Lines @('x', 'y')

    # Assert
    Assert-That -Condition (Test-HasBom $existingPath) -Message 'Rewriting an existing BOM file keeps the BOM'
    Assert-Equal -Expected "x`r`ny`r`n" -Actual ([System.IO.File]::ReadAllText($existingPath)) -Message 'Rewriting an existing CRLF file keeps CRLF'

    # Arrange / Act - -Content is written exactly as given, no EOL appended
    $contentPath = Join-Path $tempDir 'content.txt'
    Write-TextFile -Path $contentPath -Content 'no trailing newline'

    # Assert
    Assert-Equal -Expected 'no trailing newline' -Actual ([System.IO.File]::ReadAllText($contentPath)) -Message '-Content is written exactly as given'

    # Arrange / Act - -LikeFilePath supplies encoding/EOL
    # only when -Path does not exist yet
    $likePath = Join-Path $tempDir 'like-source.txt'
    [System.IO.File]::WriteAllText($likePath, "a`r`n", [System.Text.UTF8Encoding]::new($true))
    $newViaLike = Join-Path $tempDir 'new-via-like.txt'
    Write-TextFile -Path $newViaLike -Lines @('z') -LikeFilePath $likePath

    # Assert
    Assert-That -Condition (Test-HasBom $newViaLike) -Message 'A brand new file takes its encoding from -LikeFilePath'
    Assert-Equal -Expected "z`r`n" -Actual ([System.IO.File]::ReadAllText($newViaLike)) -Message 'A brand new file takes its line ending from -LikeFilePath too'

    # Arrange / Act - -LikeFilePath is ignored once -Path already exists,
    # even pointed at a very different file
    $noBomLfPath = Join-Path $tempDir 'no-bom-lf.txt'
    [System.IO.File]::WriteAllText($noBomLfPath, "a`n", [System.Text.UTF8Encoding]::new($false))
    Write-TextFile -Path $existingPath -Lines @('after') -LikeFilePath $noBomLfPath

    # Assert
    Assert-That -Condition (Test-HasBom $existingPath) -Message 'An existing file keeps its own BOM even when -LikeFilePath points to a no-BOM file'
    Assert-Equal -Expected "after`r`n" -Actual ([System.IO.File]::ReadAllText($existingPath)) -Message 'An existing file keeps its own CRLF even when -LikeFilePath points to an LF file'

    # Arrange / Act - zero lines still emits exactly one bare line ending
    $emptyLinesPath = Join-Path $tempDir 'empty-lines.txt'
    Write-TextFile -Path $emptyLinesPath -Lines @()

    # Assert
    Assert-Equal -Expected ([Environment]::NewLine) -Actual ([System.IO.File]::ReadAllText($emptyLinesPath)) -Message 'Zero lines still writes exactly one trailing line ending'
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
