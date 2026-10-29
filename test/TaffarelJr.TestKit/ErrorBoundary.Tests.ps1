#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot 'TestKitTestHelper.ps1')
$module = Get-Module TaffarelJr.TestKit

# Every case here makes a command fail and watches how it fails. The commands
# are the kit's own assertions, so the counting that reports on this file is
# never what is being broken: a helper is replaced only between the lines that
# make one call, and a call that would reach the tally runs against a tally of
# its own.

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
        Whether it raised an error, that error's ID, category and target, how
        many objects it wrote, and how many lines it printed to the host.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Preference,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $raised = $null
    $stream = [System.Collections.Generic.List[object]]::new()
    try {
        & $ScriptBlock $Preference 6>&1 | ForEach-Object { $stream.Add($_) }
    }
    catch {
        $raised = $_
    }

    $printed = @($stream | Where-Object { $_ -is [System.Management.Automation.InformationRecord] })
    $output = @($stream | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })
    return [PSCustomObject]@{
        Raised   = $null -ne $raised
        Id       = if ($raised) { $raised.FullyQualifiedErrorId } else { '' }
        Category = if ($raised) { "$($raised.CategoryInfo.Category)" } else { '' }
        Target   = if ($raised) { $raised.TargetObject } else { $null }
        Output   = $output.Count
        Printed  = $printed.Count
    }
}
function Enable-HelperFailure {
    <#
    .SYNOPSIS
        Makes one of the module's private functions fail.
    .DESCRIPTION
        Not exported - a test-only fixture, for a command that has no failing
        input to give. Returns what Disable-HelperFailure needs to put the
        function back.
    .PARAMETER Name
        The private function that fails.
    .OUTPUTS
        The function's own script block.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $original = & $module {
        param($name)
        (Get-Command -Name $name -CommandType Function).ScriptBlock
    } $Name
    & $module {
        param($name)
        $failing = { throw 'helper failed' }
        Set-Item -Path "function:script:$name" -Value $failing
    } $Name
    return $original
}

function Disable-HelperFailure {
    <#
    .SYNOPSIS
        Puts back a private function Enable-HelperFailure made fail.
    .DESCRIPTION
        Not exported - a test-only fixture.
    .PARAMETER Name
        The private function.
    .PARAMETER Original
        What Enable-HelperFailure returned.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Original
    )

    & $module {
        param($name, $body)
        Set-Item -Path "function:script:$name" -Value $body
    } $Name $Original
}

$preferences = 'SilentlyContinue', 'Ignore', 'Stop', 'Continue'
$helperFailed = @('helper failed', 'helper failed', 'helper failed', 'helper failed')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - counting a result made to fail
$original = Enable-HelperFailure -Name 'Add-TestResult'

# Act - Assert-That
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        Assert-That -Condition $true -Message 'never counted' -ErrorAction $action
    }
}
Disable-HelperFailure -Name 'Add-TestResult' -Original $original

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'An assertion that cannot be counted raises an error whatever -ErrorAction says'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.Printed) `
    -Message 'and prints no line saying it passed'
Assert-Equal -Expected @('RuntimeException,Assert-That', 'RuntimeException,Assert-That',
    'RuntimeException,Assert-That', 'RuntimeException,Assert-That') -Actual @($outcomes.Id) `
    -Message 'The error ID names the kind of failure and the command'
Assert-Equal -Expected @('InvalidOperation', 'InvalidOperation', 'InvalidOperation', 'InvalidOperation') `
    -Actual @($outcomes.Category) -Message 'and the category is an invalid operation'
Assert-Equal -Expected $helperFailed -Actual @($outcomes.Target) -Message 'and the target is what was thrown'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - comparing values made to fail
$original = Enable-HelperFailure -Name 'Test-ValueEqual'

# Act - Assert-Equal
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        Assert-Equal -Expected 1 -Actual 1 -Message 'never compared' -ErrorAction $action
    }
}
Disable-HelperFailure -Name 'Test-ValueEqual' -Original $original

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A comparison that fails raises an error whatever -ErrorAction says'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.Printed) -Message 'and prints no line'
Assert-Equal -Expected @('RuntimeException,Assert-Equal', 'RuntimeException,Assert-Equal',
    'RuntimeException,Assert-Equal', 'RuntimeException,Assert-Equal') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - recording a verdict made to fail
$original = Enable-HelperFailure -Name 'Assert-That'

# Act - Assert-Throws
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        Assert-Throws -ScriptBlock { throw 'expected' } -Message 'never recorded' -ErrorAction $action
    }
}
Disable-HelperFailure -Name 'Assert-That' -Original $original

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A verdict that cannot be recorded raises an error whatever -ErrorAction says'
Assert-Equal -Expected @('RuntimeException,Assert-Throws', 'RuntimeException,Assert-Throws',
    'RuntimeException,Assert-Throws', 'RuntimeException,Assert-Throws') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - reading the tally made to fail
$original = Enable-HelperFailure -Name 'Reset-TestTally'

# Act - Complete-TestRun
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        $common = @{ ErrorAction = $action }
        Invoke-WithTally -Passed 2 -Failed 1 -ScriptBlock { Complete-TestRun @common }
    }
}
Disable-HelperFailure -Name 'Reset-TestTally' -Original $original

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A tally that cannot be read raises an error whatever -ErrorAction says'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.Printed) -Message 'and prints no tally line'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.Output) -Message 'and returns no exit code'
Assert-Equal -Expected @('RuntimeException,Complete-TestRun', 'RuntimeException,Complete-TestRun',
    'RuntimeException,Complete-TestRun', 'RuntimeException,Complete-TestRun') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'

#───────────────────────────────────────────────────────────────────────────────
# Act - Skip-TestRun, after assertions have run
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        $common = @{ ErrorAction = $action }
        Invoke-WithTally -Passed 1 -Failed 0 -ScriptBlock { Skip-TestRun -Reason 'too late' @common }
    }
}

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A skip after assertions raises an error whatever -ErrorAction says'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.Printed) `
    -Message 'and prints no skipped line, so the file is not taken for a skipped one'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.Output) -Message 'and returns no exit code'
Assert-Equal -Expected @('RuntimeException,Skip-TestRun', 'RuntimeException,Skip-TestRun',
    'RuntimeException,Skip-TestRun', 'RuntimeException,Skip-TestRun') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'
Assert-Equal -Expected @('InvalidOperation', 'InvalidOperation', 'InvalidOperation', 'InvalidOperation') `
    -Actual @($outcomes.Category) -Message 'and an invalid-operation category'
Assert-That -Condition ($outcomes[0].Target -like '*after assertions ran*') -Message 'whose target is the message'

#───────────────────────────────────────────────────────────────────────────────
# Act - the commands that run a script block, given one that throws
$outcomes = foreach ($preference in $preferences) {
    [PSCustomObject]@{
        HostOutput    = Get-ErrorOutcome -Preference $preference -ScriptBlock {
            param($action)
            Get-HostOutput -ScriptBlock { throw 'block failed' } -ErrorAction $action
        }
        WarningOutput = Get-ErrorOutcome -Preference $preference -ScriptBlock {
            param($action)
            Get-WarningOutput -ScriptBlock { throw 'block failed' } -ErrorAction $action
        }
        WhatIfOutput  = Get-ErrorOutcome -Preference $preference -ScriptBlock {
            param($action)
            Get-WhatIfOutput -ScriptBlock { throw 'block failed' } -ErrorAction $action
        }
        SplitLocation = Get-ErrorOutcome -Preference $preference -ScriptBlock {
            param($action)
            Use-SplitLocation -Location $PSScriptRoot -ProcessDirectory $PSScriptRoot `
                -ScriptBlock { throw 'block failed' } -ErrorAction $action
        }
    }
}

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.HostOutput.Raised) `
    -Message 'A block that throws is raised by Get-HostOutput whatever -ErrorAction says'
Assert-Equal -Expected @('RuntimeException,Get-HostOutput', 'RuntimeException,Get-HostOutput',
    'RuntimeException,Get-HostOutput', 'RuntimeException,Get-HostOutput') -Actual @($outcomes.HostOutput.Id) `
    -Message 'under its error ID'
Assert-Equal -Expected @('block failed', 'block failed', 'block failed', 'block failed') `
    -Actual @($outcomes.HostOutput.Target) -Message 'with what the block threw as the target'
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.WarningOutput.Raised) `
    -Message 'and by Get-WarningOutput'
Assert-Equal -Expected @('RuntimeException,Get-WarningOutput', 'RuntimeException,Get-WarningOutput',
    'RuntimeException,Get-WarningOutput', 'RuntimeException,Get-WarningOutput') `
    -Actual @($outcomes.WarningOutput.Id) -Message 'under its error ID'
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.WhatIfOutput.Raised) `
    -Message 'and by Get-WhatIfOutput'
Assert-Equal -Expected @('RuntimeException,Get-WhatIfOutput', 'RuntimeException,Get-WhatIfOutput',
    'RuntimeException,Get-WhatIfOutput', 'RuntimeException,Get-WhatIfOutput') `
    -Actual @($outcomes.WhatIfOutput.Id) -Message 'under its error ID'
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.SplitLocation.Raised) `
    -Message 'and by Use-SplitLocation'
Assert-Equal -Expected @('RuntimeException,Use-SplitLocation', 'RuntimeException,Use-SplitLocation',
    'RuntimeException,Use-SplitLocation', 'RuntimeException,Use-SplitLocation') `
    -Actual @($outcomes.SplitLocation.Id) -Message 'under its error ID'
Assert-Equal -Expected @('InvalidOperation', 'InvalidOperation', 'InvalidOperation', 'InvalidOperation') `
    -Actual @($outcomes.SplitLocation.Category) -Message 'and an invalid-operation category'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a plain script, with no try or catch, that skips after an assertion under -ErrorAction
# SilentlyContinue, which is where a plain throw is skipped and the command carries on
$script = @"
Import-Module '$modulePath'
Assert-That -Condition `$true -Message 'one'
Skip-TestRun -Reason 'too late' -ErrorAction SilentlyContinue
"@

# Act
$run = @(& pwsh -NoProfile -NonInteractive -Command $script 2>&1 | ForEach-Object { "$_" })

# Assert
Assert-That -Condition ($run -notcontains 'skipped - too late') `
    -Message 'A plain script is not told the file was skipped after it asserted, even under SilentlyContinue'
Assert-That -Condition (($run -join ' ') -like '*after assertions ran*') `
    -Message 'and the error is reported, not swallowed'

exit (Complete-TestRun)
