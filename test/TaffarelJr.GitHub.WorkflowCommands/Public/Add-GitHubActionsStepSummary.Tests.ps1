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

$limit = 1024 * 1024
$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $path = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $sandbox -Name 'summary.md'

    # Act
    Add-GitHubActionsStepSummary -Markdown '## Results'
    Add-GitHubActionsStepSummary -Markdown '- all green'
    $text = [File]::ReadAllText($path)

    # Assert
    Assert-Equal -Expected "## Results`n- all green`n" -Actual $text `
        -Message 'Each call appends its Markdown, exactly as given, with one trailing newline'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $path = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $sandbox -Name 'piped.md'

    # Act
    '# Title', '', 'body' | Add-GitHubActionsStepSummary
    $text = [File]::ReadAllText($path)

    # Assert
    Assert-Equal -Expected "# Title`n`nbody`n" -Actual $text `
        -Message 'Each piped string is appended as a line, an empty one included'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a summary 4 bytes short of the limit
    $path = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $sandbox -Name 'nearly-full.md'
    [File]::WriteAllText($path, ('x' * ($limit - 4)))

    # Act - 3 bytes and a newline
    Add-GitHubActionsStepSummary -Markdown 'end'

    # Assert
    Assert-Equal -Expected ([long]$limit) -Actual ([FileInfo]::new($path).Length) `
        -Message 'Content that brings the summary to exactly 1 MiB is written'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a summary 2 bytes short of the limit
    $path = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $sandbox -Name 'multi-byte.md'
    [File]::WriteAllText($path, ('x' * ($limit - 2)))

    # Act / Assert - one character and a newline, but 3 bytes
    Assert-Throws -ScriptBlock { Add-GitHubActionsStepSummary -Markdown 'é' } `
        -MessageLike "*Writing 3 more byte(s)*past its 1 MiB limit ($($limit - 2) already written)*" `
        -Message 'The size is counted in UTF-8 bytes, not characters'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - content that would push the summary past the 1 MiB limit
    $path = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $sandbox -Name 'huge.md'
    [File]::WriteAllText($path, ('x' * $limit))

    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitHubActionsStepSummary -Markdown '' } `
        -MessageLike "*would push this step's summary past its 1 MiB limit*" `
        -Message 'Writing past the 1 MiB limit throws instead of truncating silently, even a lone newline'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative path, with PowerShell and the process in different
    # folders and a full summary in the process's one
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null
    $hereFile = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $here -Name 'summary.md'
    $thereFile = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $there -Name 'summary.md'
    [File]::WriteAllText($thereFile, ('x' * $limit))
    $env:GITHUB_STEP_SUMMARY = 'summary.md'

    # Act
    Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        Add-GitHubActionsStepSummary -Markdown 'here'
    }

    # Assert
    Assert-Equal -Expected "here`n" -Actual ([File]::ReadAllText($hereFile)) `
        -Message 'A relative path is measured and written at PowerShell''s location, not the process''s'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - not running inside a step
    Remove-Item Env:\GITHUB_STEP_SUMMARY -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitHubActionsStepSummary -Markdown 'x' } `
        -MessageLike '*GITHUB_STEP_SUMMARY is not set*' `
        -Message 'With GITHUB_STEP_SUMMARY unset, Add-GitHubActionsStepSummary throws'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf, and with Markdown piped in
$sandbox = New-WorkflowCommandsSandbox
try {
    $path = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $sandbox

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Add-GitHubActionsStepSummary -Markdown '# BODY_SENTINEL' -WhatIf
        'one SENTINEL', 'two SENTINEL' | Add-GitHubActionsStepSummary -WhatIf
    }

    # Assert
    $line = "What if: Performing the operation ""Append to the step summary"" on target ""$path""."
    Assert-Equal -Expected @($line, $line, $line) -Actual $whatIf.Messages `
        -Message '-WhatIf names the summary file once for each call'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') -Message 'and never the Markdown'
    Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) `
        -Message 'and nothing is written to the summary'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the file GITHUB_STEP_SUMMARY names is not there
$sandbox = New-WorkflowCommandsSandbox
try {
    $env:GITHUB_STEP_SUMMARY = Join-Path $sandbox 'missing.md'

    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitHubActionsStepSummary -Markdown 'x' } `
        -MessageLike '*GITHUB_STEP_SUMMARY points at*which is not a file*' -Message 'A missing summary file throws'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $env:GITHUB_STEP_SUMMARY) `
        -Message 'and is not created'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a summary already at its limit
$sandbox = New-WorkflowCommandsSandbox
try {
    $path = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $sandbox
    [IO.File]::WriteAllBytes($path, [byte[]]::new(1024 * 1024))

    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitHubActionsStepSummary -Markdown 'x' -WhatIf } `
        -MessageLike "*would push this step's summary past its 1 MiB limit*" `
        -Message 'With -WhatIf, Markdown past the limit is still refused'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$sandbox = New-WorkflowCommandsSandbox
try {
    $path = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $sandbox

    # Act
    Add-GitHubActionsStepSummary -Markdown '# Results' -Confirm:$false

    # Assert
    Assert-Equal -Expected "# Results`n" -Actual ([IO.File]::ReadAllText($path)) `
        -Message '-Confirm:$false writes the Markdown'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
