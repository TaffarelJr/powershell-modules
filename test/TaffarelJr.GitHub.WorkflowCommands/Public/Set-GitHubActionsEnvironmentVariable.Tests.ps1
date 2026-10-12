#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

$originalEnv = $env:GITHUB_ENV
$tempDir = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:GITHUB_ENV = Join-Path $tempDir 'env.txt'

    # Act
    Set-GitHubActionsEnvironmentVariable -Name 'BUILD_CONFIG' -Value 'Release'
    $text = [File]::ReadAllText($env:GITHUB_ENV)

    # Assert
    Assert-That -Condition ($text -match '^BUILD_CONFIG<<ghadelimiter_[0-9a-f-]+\r?\nRelease\r?\nghadelimiter_[0-9a-f-]+\r?\n$') `
        -Message 'The variable is appended to the env file in the heredoc form'
    Assert-Equal -Expected 'Release' -Actual $env:BUILD_CONFIG -Message 'The variable also takes effect in this process immediately'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - not running inside a step
    Remove-Item Env:\GITHUB_ENV -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name 'X' -Value 'y' } -Message 'With GITHUB_ENV unset, Set-GitHubActionsEnvironmentVariable throws'
}
finally {
    if ($null -eq $originalEnv) { Remove-Item Env:\GITHUB_ENV -ErrorAction SilentlyContinue } else { $env:GITHUB_ENV = $originalEnv }
    Remove-Item Env:\BUILD_CONFIG -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
