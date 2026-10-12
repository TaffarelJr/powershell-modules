#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot 'GitHubWorkflowCommandsTestHelper.ps1')
$module = Get-Module TaffarelJr.GitHub.WorkflowCommands

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case.
$assertMessage = {
    param([scriptblock]$Block, [string]$Expected, [string]$Name)
    Assert-Throws -ScriptBlock $Block -MessageLike ([WildcardPattern]::Escape($Expected)) -Message $Name
}

# A folder name holds ':' only off Windows, and the colon is what lets a path be
# read as USER:PASSWORD@; on Windows the drive's own colon does.
$credentialFolder = if ($IsWindows) { 'SENTINEL@h.example' } else { 'user:SENTINEL@h.example' }
$sandbox = New-WorkflowCommandsSandbox
$credentialPath = Join-Path $sandbox $credentialFolder
New-Item -ItemType Directory -Path $credentialPath | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a name that looks like a credential, for each function that
    # writes one to a runner file
    $null = New-CommandFile -Variable 'GITHUB_OUTPUT' -Directory $sandbox
    $null = New-CommandFile -Variable 'GITHUB_STATE' -Directory $sandbox
    $null = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubActionsOutput -Name 'user:SENTINEL@h.example' -Value 'v' -WhatIf
        Save-GitHubActionsState -Name 'user:SENTINEL@h.example' -Value 'v' -WhatIf
        Set-GitHubActionsEnvironmentVariable -Name 'user:SENTINEL@h.example' -Value 'v' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Set step output" on target "***@h.example".'
        'What if: Performing the operation "Save action state" on target "***@h.example".'
        'What if: Performing the operation "Set environment variable for later steps and this process"' +
        ' on target "***@h.example".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf shows no credential in a name'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the step summary file in a folder whose name holds the credential
    $null = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $credentialPath -Name 'summary.md'

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Add-GitHubActionsStepSummary -Markdown 'x' -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Append to the step summary" on target "*[*]@h.example?summary.md".'
    Assert-That -Condition (1 -eq @($whatIf.Messages).Count -and $whatIf.Messages[0] -clike $expected) `
        -Message '-WhatIf shows no credential in the path of the step summary file'
    Assert-Equal -Expected 0 -Actual @($whatIf.Messages -match 'SENTINEL').Count -Message 'so no line holds it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a runner file that is a path on another provider, one that
    # PowerShell cannot resolve at all, and a file that is not there; each as a
    # value that looks like a credential
    $missing = Join-Path $credentialPath 'none.txt'
    $notResolved = 'GITHUB_OUTPUT is ''***@h.example/o/r'', which PowerShell cannot resolve: the path holds a' +
    ' credential, so the reason PowerShell gives is not shown'
    $otherProvider = 'GITHUB_OUTPUT is ''***@h.example/x'', which resolves to a path on the Environment provider,' +
    ' not a file; give a full file-system path, or run from a file-system location.'

    # Act / Assert
    $env:GITHUB_OUTPUT = 'Env:/user:SENTINEL@h.example/x'
    & $assertMessage {
        Set-GitHubActionsOutput -Name 'n' -Value 'v'
    } $otherProvider 'Resolve-GitHubActionsFilePath shows no credential in a variable on another provider'
    $env:GITHUB_OUTPUT = 'SENTINEL:x-oauth-basic@h.example/o/r'
    & $assertMessage {
        Set-GitHubActionsOutput -Name 'n' -Value 'v'
    } $notResolved 'and none in a value PowerShell cannot resolve, nor in the reason it gives'
    $env:GITHUB_OUTPUT = $missing
    Assert-Throws -ScriptBlock {
        Set-GitHubActionsOutput -Name 'n' -Value 'v'
    } -MessageLike ('GITHUB_OUTPUT points at ''*[*]@h.example?none.txt'', which is not a file; the runner creates' +
        ' it for each step, so check the variable''s value.') `
        -Message 'and none in the path of a file that is not there'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a directory for PATH that looks like a credential, with the path file in place
    $null = New-CommandFile -Variable 'GITHUB_PATH' -Directory $sandbox
    $otherProvider = '-Path is ''***@h.example/x'', which resolves to a path on the Environment provider, not a' +
    ' folder; give a full file-system path, or run from a file-system location.'
    $notResolved = '-Path is ''***@h.example/bin'', which PowerShell cannot resolve: the path holds a credential,' +
    ' so the reason PowerShell gives is not shown'

    # Act / Assert
    & $assertMessage {
        Add-GitHubActionsPath -Path 'Env:/user:SENTINEL@h.example/x'
    } $otherProvider 'Add-GitHubActionsPath shows no credential in a path on another provider'
    & $assertMessage {
        Add-GitHubActionsPath -Path 'SENTINEL:x-oauth-basic@h.example/bin'
    } $notResolved 'and none in a path PowerShell cannot resolve, nor in the reason it gives'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a line number that is no number, and looks like a credential
    $expected = '-Line is ''***@h.example'', which is not a whole number: give one from 1 to 2147483647,' +
    ' or leave it out.'

    # Act / Assert
    & $assertMessage {
        Write-GitHubActionsError -Message 'm' -Line 'user:SENTINEL@h.example'
    } $expected 'Write-GitHubActionsError shows no credential in a position that is no number'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a runner file another handle holds open, in a folder whose name holds the credential
    $locked = Join-Path $credentialPath 'locked.txt'
    $handle = [File]::Open($locked, [FileMode]::Create, [FileAccess]::ReadWrite, [FileShare]::None)
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $module { param($p) Add-GitHubActionsFileText -Variable 'GITHUB_ENV' -Path $p -Text 'x' } $locked
        } -MessageLike ('Could not write to the file GITHUB_ENV points at (''*[*]@h.example?locked.txt''): ' +
            '*''*[*]@h.example?locked.txt''*') -ExceptionType ([IOException]) `
            -Message 'A failed write shows no credential, in the path or in the reason that names it'
    }
    finally {
        $handle.Dispose()
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act - what a caller asks the log to show, which is written as given
    $lines = @(Get-WorkflowCommand -ScriptBlock {
            Write-GitHubActionsWarning -Message 'uses: actions/checkout@v4' -Title 'Pin: owner@ref'
            Write-GitHubActionsDebug -Message 'cloning https://user:SENTINEL@h.example/o/r'
            Hide-GitHubActionsValue -Value 'https://user:SENTINEL@h.example/x'
        })

    # Assert
    $expected = @(
        '::warning title=Pin%3A owner@ref::uses: actions/checkout@v4'
        '::debug::cloning https://user:SENTINEL@h.example/o/r'
        '::add-mask::https://user:SENTINEL@h.example/x'
    )
    Assert-Equal -Expected $expected -Actual $lines `
        -Message 'An annotation, a debug line, and a value to mask are written as given: the caller chose that text'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
