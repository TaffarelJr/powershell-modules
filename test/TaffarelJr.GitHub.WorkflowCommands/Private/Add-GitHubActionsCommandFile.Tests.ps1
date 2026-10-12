#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/Private/Add-GitHubActionsCommandFile.ps1')

$tempDir = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $path = Join-Path $tempDir 'single.txt'

    # Act
    Add-GitHubActionsCommandFile -Path $path -Name 'greeting' -Value 'hello'
    $text = [File]::ReadAllText($path)

    # Assert
    Assert-That -Condition ($text -match '^greeting<<ghadelimiter_[0-9a-f-]+\r?\nhello\r?\nghadelimiter_[0-9a-f-]+\r?\n$') `
        -Message 'A single call writes the name<<delimiter / value / delimiter heredoc form'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a value containing its own newlines, which a plain
    # NAME=VALUE line could never carry safely
    $path = Join-Path $tempDir 'multiline.txt'

    # Act
    Add-GitHubActionsCommandFile -Path $path -Name 'notes' -Value "line one`nline two"
    $text = [File]::ReadAllText($path)

    # Assert
    Assert-That -Condition ($text -match "(?s)^notes<<(?<d>ghadelimiter_[0-9a-f-]+)\r?\nline one\r?\nline two\r?\n\k<d>\r?\n`$") `
        -Message 'A multi-line value is carried intact between the delimiters'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two calls to the same file append rather than overwrite
    $path = Join-Path $tempDir 'append.txt'

    # Act
    Add-GitHubActionsCommandFile -Path $path -Name 'first' -Value '1'
    Add-GitHubActionsCommandFile -Path $path -Name 'second' -Value '2'
    $text = [File]::ReadAllText($path)

    # Assert
    Assert-That -Condition ($text -match 'first<<') -Message 'The first call''s pair is still present'
    Assert-That -Condition ($text -match 'second<<') -Message 'A second call appends rather than overwriting the first'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two calls get two different delimiters, so a value that
    # happens to equal one call's delimiter can never collide with the other's
    $path = Join-Path $tempDir 'unique-delimiters.txt'

    # Act
    Add-GitHubActionsCommandFile -Path $path -Name 'a' -Value 'x'
    Add-GitHubActionsCommandFile -Path $path -Name 'b' -Value 'y'
    $delimiters = [Regex]::Matches([File]::ReadAllText($path), 'ghadelimiter_[0-9a-f-]+') | ForEach-Object Value | Select-Object -Unique

    # Assert
    Assert-Equal -Expected 2 -Actual $delimiters.Count -Message 'Each of the two calls uses its own, different delimiter'
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
