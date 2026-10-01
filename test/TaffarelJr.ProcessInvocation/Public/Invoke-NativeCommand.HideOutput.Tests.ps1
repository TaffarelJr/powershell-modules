#Requires -Version 7.4
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ProcessInvocationTestHelper.ps1')
$module = Get-Module TaffarelJr.ProcessInvocation

function Get-CallOutcome {
    <#
    .SYNOPSIS
        Runs a script block and reports what it showed and how it ended.
    .DESCRIPTION
        Not exported - a test-only fixture. Collects the verbose lines as
        they are written, so those written before a failure are kept.
    .PARAMETER ScriptBlock
        The call to make.
    .OUTPUTS
        The error's message and rendered text (empty when nothing failed),
        and the verbose lines.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $raised = $null
    $seen = [System.Collections.Generic.List[object]]::new()
    try {
        & $ScriptBlock 4>&1 | ForEach-Object { $seen.Add($_) }
    }
    catch {
        $raised = $_
    }

    return [PSCustomObject]@{
        Message  = if ($raised) { $raised.Exception.Message } else { '' }
        Rendered = if ($raised) { ($raised | Out-String) } else { '' }
        Verbose  = @($seen | Where-Object { $_ -is [VerboseRecord] } | ForEach-Object { $_.Message })
    }
}

$printed = 'SENTINEL_PRINTED_123'
Set-Item -Path function:global:Invoke-OutputProbe -Value {
    'config: SENTINEL_PRINTED_123'
    Write-Error 'warning: SENTINEL_PRINTED_123' -ErrorAction Continue
    $global:LASTEXITCODE = 5
}

$script = '$env:PROBE_TEXT; [Console]::Error.WriteLine($env:PROBE_TEXT); exit 4'
$environment = @{ PROBE_TEXT = $printed }
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a failing command that prints, with and without -HideOutput
    $shown = Get-CallOutcome { Invoke-NativeCommand -Activity 'Testing' -Command 'Invoke-OutputProbe' }
    $hidden = Get-CallOutcome { Invoke-NativeCommand -Activity 'Testing' -Command 'Invoke-OutputProbe' -HideOutput }

    # Assert
    Assert-That -Condition $shown.Message.Contains($printed) `
        -Message 'Without -HideOutput the output is in the failure message'
    Assert-Equal -Expected 'Testing failed: Invoke-OutputProbe (exit 5)' -Actual $hidden.Message `
        -Message 'With -HideOutput the message keeps the activity, the command line and the exit code, and no output'
    Assert-That -Condition (-not $hidden.Rendered.Contains($printed)) `
        -Message 'and the error as PowerShell renders it holds none either'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - the same, with stdout and stderr kept apart, and with -Verbose
    $apart = Get-CallOutcome {
        Invoke-NativeCommand -Activity 'Testing' -Command 'Invoke-OutputProbe' -HideOutput -SeparateStderr -Verbose
    }

    # Assert
    Assert-Equal -Expected 'Testing failed: Invoke-OutputProbe (exit 5)' -Actual $apart.Message `
        -Message 'Stderr is left out as well as stdout'
    Assert-Equal -Expected @('Running: Invoke-OutputProbe') -Actual $apart.Verbose `
        -Message 'and the verbose line is the command line alone'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a program on a process of its own
    $arguments = @('-NoProfile', '-Command', $script)
    $call = & $module { param($c, $a) Format-NativeCommandLine -Command $c -Arguments $a } $pwsh $arguments

    # Act
    $program = Get-CallOutcome {
        Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument $arguments -Environment $environment `
            -HideOutput -Verbose
    }

    # Assert
    Assert-Equal -Expected "Testing failed: $call (exit 4)" -Actual $program.Message `
        -Message 'A program run directly has its stdout and stderr left out too'
    Assert-Equal -Expected @("Running: $call") -Actual $program.Verbose `
        -Message 'and the verbose line does not show the output or the environment'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a command that cannot be found
    $missing = Get-CallOutcome {
        Invoke-NativeCommand -Activity 'Testing' -Command 'this-command-does-not-exist-xyz' -HideOutput
    }

    # Assert
    Assert-That -Condition ($missing.Message -like 'Testing failed: could not run this-command-does-not-exist-xyz (*') `
        -Message ('A command that cannot be run still says why,' +
            ' which is the system''s reason and not the command''s output')

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a command that works
    $result = @(Invoke-NativeCommand -Activity 'Testing' -Command $pwsh `
            -Argument @('-NoProfile', '-Command', 'Write-Output ok') `
            -HideOutput)

    # Assert
    Assert-Equal -Expected @('ok') -Actual $result `
        -Message ('-HideOutput changes only the failure message,' +
            ' so a success still returns its output')
}
finally {
    Remove-Item -Path function:global:Invoke-OutputProbe
}

exit (Complete-TestRun)
