#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1'
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot 'ProcessInvocationTestHelper.ps1')
$module = Get-Module TaffarelJr.ProcessInvocation

function Get-ErrorOutcome {
    <#
    .SYNOPSIS
        Runs a script block under one error preference and reports what came
        of it.
    .DESCRIPTION
        Not exported - a test-only fixture. The block receives the
        preference's name to hand to -ErrorAction.
    .PARAMETER Preference
        The -ErrorAction value the block uses.
    .PARAMETER ScriptBlock
        The call to make.
    .OUTPUTS
        Whether it raised an error, that error's ID, category and target, and
        what it wrote to the pipeline, joined by a bar.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Preference,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $raised = $null
    $output = [System.Collections.Generic.List[object]]::new()
    try {
        & $ScriptBlock $Preference | ForEach-Object { $output.Add($_) }
    }
    catch {
        $raised = $_
    }

    return [PSCustomObject]@{
        Raised   = $null -ne $raised
        Id       = if ($raised) { $raised.FullyQualifiedErrorId } else { '' }
        Category = if ($raised) { "$($raised.CategoryInfo.Category)" } else { '' }
        Target   = if ($raised) { $raised.TargetObject } else { $null }
        Output   = ($output -join '|')
    }
}

function Lock-ModuleVariable {
    <#
    .SYNOPSIS
        Makes a variable the module's functions assign to read-only, so that
        assignment fails.
    .DESCRIPTION
        Not exported - a test-only fixture, for a block of a function that
        has no failing input to give.
    .PARAMETER Name
        The variable.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    & $module {
        param($name)
        New-Variable -Name $name -Value $null -Option ReadOnly, AllScope -Scope Script -Force
    } $Name
}

function Unlock-ModuleVariable {
    <#
    .SYNOPSIS
        Removes a variable Lock-ModuleVariable made.
    .DESCRIPTION
        Not exported - a test-only fixture.
    .PARAMETER Name
        The variable.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    & $module {
        param($name)
        Remove-Variable -Name $name -Scope Script -Force
    } $Name
}

$preferences = 'SilentlyContinue', 'Ignore', 'Stop', 'Continue'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a command that fails
function global:Invoke-FailingProbe { $global:LASTEXITCODE = 7 }
$failed = 'Testing failed: Invoke-FailingProbe (exit 7)'

# Act - Invoke-NativeCommand
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        Invoke-NativeCommand -Activity 'Testing' -Command 'Invoke-FailingProbe' -ErrorAction $action
    }
}
Remove-Item -Path function:global:Invoke-FailingProbe

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A failed command raises an error whatever -ErrorAction says'
Assert-Equal -Expected @('', '', '', '') -Actual @($outcomes.Output) -Message 'and returns nothing'
Assert-Equal -Expected @('RuntimeException,Invoke-NativeCommand', 'RuntimeException,Invoke-NativeCommand',
    'RuntimeException,Invoke-NativeCommand', 'RuntimeException,Invoke-NativeCommand') -Actual @($outcomes.Id) `
    -Message 'The error ID names the kind of failure and the command'
Assert-Equal -Expected @('InvalidOperation', 'InvalidOperation', 'InvalidOperation', 'InvalidOperation') `
    -Actual @($outcomes.Category) -Message 'and the category is an invalid operation'
Assert-Equal -Expected @($failed, $failed, $failed, $failed) -Actual @($outcomes.Target) `
    -Message 'and the target is the message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a working directory that is not on disk, which is a mistake in the call
$mistake = "-WorkingDirectory 'Env:\' is on the Environment provider: give a folder on disk."

# Act - Invoke-NativeRead
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        Invoke-NativeRead -Command $pwsh -WorkingDirectory 'Env:\' -ErrorAction $action
    }
}

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A mistake in a read raises an error whatever -ErrorAction says'
Assert-Equal -Expected @('', '', '', '') -Actual @($outcomes.Output) -Message 'and returns no result'
Assert-Equal -Expected @('RuntimeException,Invoke-NativeRead', 'RuntimeException,Invoke-NativeRead',
    'RuntimeException,Invoke-NativeRead', 'RuntimeException,Invoke-NativeRead') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'
Assert-Equal -Expected @($mistake, $mistake, $mistake, $mistake) -Actual @($outcomes.Target) `
    -Message 'with the message as the target'

#───────────────────────────────────────────────────────────────────────────────
# Act - Assert-ExitCode, given an exit code that is not zero
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        Assert-ExitCode 'Building' -ExitCode 1 -ErrorAction $action
    }
}

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A non-zero exit code raises an error whatever -ErrorAction says'
Assert-Equal -Expected @('RuntimeException,Assert-ExitCode', 'RuntimeException,Assert-ExitCode',
    'RuntimeException,Assert-ExitCode', 'RuntimeException,Assert-ExitCode') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'
Assert-Equal -Expected @('Building failed with exit code 1', 'Building failed with exit code 1',
    'Building failed with exit code 1', 'Building failed with exit code 1') -Actual @($outcomes.Target) `
    -Message 'with the message as the target'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the step of Hide-UrlCredential that works on text holding an @, made to fail
Lock-ModuleVariable -Name 'chars'

# Act - Hide-UrlCredential, piped three lines of which the second holds an @
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        'first', 'a@b', 'third' | Hide-UrlCredential -ErrorAction $action
    }
}
Unlock-ModuleVariable -Name 'chars'

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A line that cannot be hidden raises an error whatever -ErrorAction says'
Assert-Equal -Expected @('first', 'first', 'first', 'first') -Actual @($outcomes.Output) `
    -Message 'and stops the pipeline: the line before it comes back, the one after it does not'
Assert-Equal -Expected @('VariableNotWritable,Hide-UrlCredential', 'VariableNotWritable,Hide-UrlCredential',
    'VariableNotWritable,Hide-UrlCredential', 'VariableNotWritable,Hide-UrlCredential') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the step of Hide-MaskedValue that prepares the values, made to fail
Lock-ModuleVariable -Name 'pattern'

# Act - Hide-MaskedValue, piped two lines
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        'first', 'second' | Hide-MaskedValue -Mask 'SENTINEL_SECRET_123' -ErrorAction $action
    }
}
Unlock-ModuleVariable -Name 'pattern'

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'Values that cannot be prepared raise an error whatever -ErrorAction says'
Assert-Equal -Expected @('', '', '', '') -Actual @($outcomes.Output) -Message 'and no line comes back'
Assert-Equal -Expected @('VariableNotWritable,Hide-MaskedValue', 'VariableNotWritable,Hide-MaskedValue',
    'VariableNotWritable,Hide-MaskedValue', 'VariableNotWritable,Hide-MaskedValue') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the step of Hide-MaskedValue that works on each line, made to fail
Lock-ModuleVariable -Name 'hidden'

# Act - Hide-MaskedValue, piped two lines
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        'first', 'second' | Hide-MaskedValue -Mask 'SENTINEL_SECRET_123' -ErrorAction $action
    }
}
Unlock-ModuleVariable -Name 'hidden'

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A line that cannot be hidden raises an error whatever -ErrorAction says'
Assert-Equal -Expected @('', '', '', '') -Actual @($outcomes.Output) `
    -Message 'and stops the pipeline: no line comes back'
Assert-Equal -Expected @('VariableNotWritable,Hide-MaskedValue', 'VariableNotWritable,Hide-MaskedValue',
    'VariableNotWritable,Hide-MaskedValue', 'VariableNotWritable,Hide-MaskedValue') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a plain script, with no try or catch, that runs a failing command under -ErrorAction
# SilentlyContinue, which is where a plain throw is skipped and the command carries on
$script = @"
Import-Module '$modulePath'
`$out = `$null
`$out = Invoke-NativeCommand -Activity 'Failing' -Command '$pwsh' ``
    -Argument @('-NoProfile', '-Command', 'Write-Output seen; exit 3') -ErrorAction SilentlyContinue
"result: [`$out]"
"@

# Act
$run = @(& $pwsh -NoProfile -NonInteractive -Command $script 2>&1 | ForEach-Object { "$_" })

# Assert
Assert-That -Condition ($run -contains 'result: []') `
    -Message 'A plain script is given no output from a command that failed, even under SilentlyContinue'
Assert-That -Condition (($run -join ' ') -like '*Failing failed*') -Message 'and the error is reported, not swallowed'

exit (Complete-TestRun)
