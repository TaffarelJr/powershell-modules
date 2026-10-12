#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

$originalPathFile = $env:GITHUB_PATH
$originalPath = $env:PATH
$tempDir = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:GITHUB_PATH = Join-Path $tempDir 'path.txt'
    $toolDir = Join-Path $tempDir 'tools'

    # Act
    Add-GitHubActionsPath -Path $toolDir
    $text = [File]::ReadAllText($env:GITHUB_PATH)

    # Assert
    Assert-Equal -Expected "$toolDir`n" -Actual $text -Message 'The directory is appended to the path file as a plain, unescaped line'
    Assert-That -Condition ($env:PATH.StartsWith($toolDir + [Path]::PathSeparator)) -Message 'The directory is also prepended to this process''s own PATH immediately'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a second directory, added after the first
    $secondDir = Join-Path $tempDir 'more-tools'

    # Act
    Add-GitHubActionsPath -Path $secondDir
    $text = [File]::ReadAllText($env:GITHUB_PATH)

    # Assert
    Assert-Equal -Expected "$toolDir`n$secondDir`n" -Actual $text -Message 'A second call appends another line rather than overwriting the first'
    Assert-That -Condition ($env:PATH.StartsWith($secondDir + [Path]::PathSeparator)) -Message 'The most recently added directory comes first on PATH'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - not running inside a step
    Remove-Item Env:\GITHUB_PATH -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitHubActionsPath -Path $toolDir } -Message 'With GITHUB_PATH unset, Add-GitHubActionsPath throws'
}
finally {
    if ($null -eq $originalPathFile) { Remove-Item Env:\GITHUB_PATH -ErrorAction SilentlyContinue } else { $env:GITHUB_PATH = $originalPathFile }
    $env:PATH = $originalPath
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
