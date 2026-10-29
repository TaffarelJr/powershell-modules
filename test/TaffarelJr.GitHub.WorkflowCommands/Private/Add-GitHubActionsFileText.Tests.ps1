#Requires -Version 7.4
using namespace System.IO
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')
$module = Get-Module TaffarelJr.GitHub.WorkflowCommands

$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an empty file, as the runner creates, where a byte order mark
    # would be written if one were
    $path = Join-Path $sandbox 'summary.md'
    [File]::WriteAllBytes($path, [byte[]]@())

    # Act
    & $module { param($p) Add-GitHubActionsFileText -Variable 'GITHUB_STEP_SUMMARY' -Path $p -Text "é ✓`n" } $path

    # Assert
    Assert-Equal -Expected ([byte[]](0xC3, 0xA9, 0x20, 0xE2, 0x9C, 0x93, 0x0A)) -Actual ([File]::ReadAllBytes($path)) `
        -Message 'The text is written exactly as given, as UTF-8 with no byte order mark'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    & $module { param($p) Add-GitHubActionsFileText -Variable 'GITHUB_STEP_SUMMARY' -Path $p -Text "more`n" } $path

    # Assert
    Assert-Equal -Expected ([Encoding]::UTF8.GetBytes("é ✓`nmore`n")) -Actual ([File]::ReadAllBytes($path)) `
        -Message 'A second call appends after what is there'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file another handle holds open with no sharing
    $locked = Join-Path $sandbox 'locked.txt'
    $handle = [File]::Open($locked, [FileMode]::Create, [FileAccess]::ReadWrite, [FileShare]::None)
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $module { param($p) Add-GitHubActionsFileText -Variable 'GITHUB_ENV' -Path $p -Text 'x' } $locked
        } -MessageLike "*Could not write to the file GITHUB_ENV points at ('$locked')*" -ExceptionType ([IOException]) `
            -Message 'A failed write throws naming the variable and the path, with the reason underneath'
    }
    finally {
        $handle.Dispose()
    }
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
