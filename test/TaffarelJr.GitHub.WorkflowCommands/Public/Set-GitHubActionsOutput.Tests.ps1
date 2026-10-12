#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

$originalOutput = $env:GITHUB_OUTPUT
$tempDir = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:GITHUB_OUTPUT = Join-Path $tempDir 'output.txt'

    # Act
    Set-GitHubActionsOutput -Name 'version' -Value '1.2.3'
    $text = [File]::ReadAllText($env:GITHUB_OUTPUT)

    # Assert
    Assert-That -Condition ($text -match '^version<<ghadelimiter_[0-9a-f-]+\r?\n1\.2\.3\r?\nghadelimiter_[0-9a-f-]+\r?\n$') `
        -Message 'The output is appended in the heredoc form'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two outputs in the same step
    $env:GITHUB_OUTPUT = Join-Path $tempDir 'two-outputs.txt'

    # Act - pipeline input by property name
    [PSCustomObject]@{ Name = 'a'; Value = '1' }, [PSCustomObject]@{ Name = 'b'; Value = '2' } | Set-GitHubActionsOutput
    $text = [File]::ReadAllText($env:GITHUB_OUTPUT)

    # Assert
    Assert-That -Condition ($text -match 'a<<') -Message 'The first piped output is present'
    Assert-That -Condition ($text -match 'b<<') -Message 'The second piped output is present'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - not running inside a step
    Remove-Item Env:\GITHUB_OUTPUT -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitHubActionsOutput -Name 'x' -Value 'y' } -Message 'With GITHUB_OUTPUT unset, Set-GitHubActionsOutput throws'
}
finally {
    if ($null -eq $originalOutput) { Remove-Item Env:\GITHUB_OUTPUT -ErrorAction SilentlyContinue } else { $env:GITHUB_OUTPUT = $originalOutput }
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
