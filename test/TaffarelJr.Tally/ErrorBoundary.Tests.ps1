#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
$module = Get-Module TaffarelJr.Tally

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
        how many objects it wrote.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Preference,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $raised = $null
    $output = @()
    try {
        $output = @(& $ScriptBlock $Preference)
    }
    catch {
        $raised = $_
    }

    return [PSCustomObject]@{
        Raised   = $null -ne $raised
        Id       = if ($raised) { $raised.FullyQualifiedErrorId } else { '' }
        Category = if ($raised) { "$($raised.CategoryInfo.Category)" } else { '' }
        Target   = if ($raised) { $raised.TargetObject } else { $null }
        Output   = $output.Count
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
$badNameMessage = "' bad' is not a valid tally name: a name must be one line, with no leading or trailing whitespace."

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pipeline whose second name is not a valid one, under each error preference
# Act
$outcomes = foreach ($preference in $preferences) {
    Clear-Tally
    $outcome = Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        'first', ' bad', 'third' | Add-Tally -ErrorAction $action
    }

    [PSCustomObject]@{
        Outcome = $outcome
        Counted = Format-Tally -Name 'first', 'third'
    }
}

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Outcome.Raised) `
    -Message 'A name that cannot be counted raises an error whatever -ErrorAction says'
Assert-Equal -Expected @('1 first - 0 third', '1 first - 0 third', '1 first - 0 third', '1 first - 0 third') `
    -Actual @($outcomes.Counted) `
    -Message 'and stops the pipeline: the name before it is counted, the name after it is not'
Assert-Equal -Expected @('RuntimeException,Add-Tally', 'RuntimeException,Add-Tally', 'RuntimeException,Add-Tally',
    'RuntimeException,Add-Tally') -Actual @($outcomes.Outcome.Id) `
    -Message 'The error ID names the kind of failure and the command'
Assert-Equal -Expected @('InvalidOperation', 'InvalidOperation', 'InvalidOperation', 'InvalidOperation') `
    -Actual @($outcomes.Outcome.Category) -Message 'and the category is an invalid operation'
Assert-Equal -Expected @($badNameMessage, $badNameMessage, $badNameMessage, $badNameMessage) `
    -Actual @($outcomes.Outcome.Target) -Message 'and the target is what was thrown'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.Outcome.Output) -Message 'and nothing is written'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a count that cannot take the amount, which Add-Tally refuses itself
# Act
$outcomes = foreach ($preference in $preferences) {
    Clear-Tally
    Add-Tally -Name 'big' -Amount ([long]::MaxValue)
    $outcome = Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        Add-Tally -Name 'big' -ErrorAction $action
    }

    [PSCustomObject]@{
        Outcome = $outcome
        Counted = Get-Tally -Name 'big'
    }
}

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Outcome.Raised) `
    -Message 'An add that would overflow raises an error whatever -ErrorAction says'
Assert-Equal -Expected @([long]::MaxValue, [long]::MaxValue, [long]::MaxValue, [long]::MaxValue) `
    -Actual @($outcomes.Counted) -Message 'and leaves the count as it was'
Assert-Equal -Expected @('RuntimeException,Add-Tally', 'RuntimeException,Add-Tally', 'RuntimeException,Add-Tally',
    'RuntimeException,Add-Tally') -Actual @($outcomes.Outcome.Id) -Message 'under the same error ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a name that is not valid, given to each command that reads or clears one
# Act
$outcomes = foreach ($preference in $preferences) {
    [PSCustomObject]@{
        ReadOutcome   = Get-ErrorOutcome -Preference $preference -ScriptBlock {
            param($action)
            Get-Tally -Name ' bad' -ErrorAction $action
        }
        ClearOutcome  = Get-ErrorOutcome -Preference $preference -ScriptBlock {
            param($action)
            Clear-Tally -Name ' bad' -ErrorAction $action
        }
        FormatOutcome = Get-ErrorOutcome -Preference $preference -ScriptBlock {
            param($action)
            Format-Tally -Name ' bad' -ErrorAction $action
        }
    }
}

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.ReadOutcome.Raised) `
    -Message 'Get-Tally raises an error for a name that cannot be one, whatever -ErrorAction says'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.ReadOutcome.Output) -Message 'and writes nothing'
Assert-Equal -Expected @('RuntimeException,Get-Tally', 'RuntimeException,Get-Tally', 'RuntimeException,Get-Tally',
    'RuntimeException,Get-Tally') -Actual @($outcomes.ReadOutcome.Id) -Message 'under its own error ID'
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.ClearOutcome.Raised) `
    -Message 'Clear-Tally raises an error for it too'
Assert-Equal -Expected @('RuntimeException,Clear-Tally', 'RuntimeException,Clear-Tally',
    'RuntimeException,Clear-Tally', 'RuntimeException,Clear-Tally') -Actual @($outcomes.ClearOutcome.Id) `
    -Message 'under its own error ID'
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.FormatOutcome.Raised) `
    -Message 'and Format-Tally'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.FormatOutcome.Output) -Message 'which writes no line'
Assert-Equal -Expected @('RuntimeException,Format-Tally', 'RuntimeException,Format-Tally',
    'RuntimeException,Format-Tally', 'RuntimeException,Format-Tally') -Actual @($outcomes.FormatOutcome.Id) `
    -Message 'under its own error ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a line that Read-Tally could not read back, which Format-Tally refuses after it has built it
Clear-Tally

# Act
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        Format-Tally -Name 'a - b' -ErrorAction $action
    }
}

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A line that would not read back raises an error whatever -ErrorAction says'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.Output) -Message 'and is not written'
Assert-Equal -Expected @('RuntimeException,Format-Tally', 'RuntimeException,Format-Tally',
    'RuntimeException,Format-Tally', 'RuntimeException,Format-Tally') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'
Assert-Equal -Expected @('InvalidOperation', 'InvalidOperation', 'InvalidOperation', 'InvalidOperation') `
    -Actual @($outcomes.Category) -Message 'and an invalid-operation category'
Assert-That -Condition ($outcomes[0].Target -like "The tally entry '0 a - b' would not read back:*") `
    -Message 'whose target is the message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the state the commands take before they work, made unusable
Lock-ModuleVariable -Name 'state'

# Act
$add = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock {
    param($action)
    Add-Tally -Name 'x' -ErrorAction $action
}
$clear = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock {
    param($action)
    Clear-Tally -ErrorAction $action
}
$get = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock {
    param($action)
    Get-Tally -ErrorAction $action
}
$format = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock {
    param($action)
    Format-Tally -ErrorAction $action
}
Unlock-ModuleVariable -Name 'state'

# Assert
Assert-Equal -Expected 'VariableNotWritable,Get-TallyState,Add-Tally' -Actual $add.Id `
    -Message 'A failure before Add-Tally has anything to add is raised, not skipped'
Assert-Equal -Expected 'VariableNotWritable,Get-TallyState,Clear-Tally' -Actual $clear.Id `
    -Message 'and so is one before Clear-Tally'
Assert-Equal -Expected 'VariableNotWritable,Get-TallyState,Get-Tally' -Actual $get.Id `
    -Message 'and one before Get-Tally'
Assert-Equal -Expected 'VariableNotWritable,Get-TallyState,Format-Tally' -Actual $format.Id `
    -Message 'and one in the last step of Format-Tally'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($add.Output, $clear.Output, $get.Output, $format.Output) `
    -Message 'none of them writes anything'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the first step of Format-Tally, made to fail
Lock-ModuleVariable -Name 'requested'

# Act
$format = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock {
    param($action)
    Format-Tally -ErrorAction $action
}
Unlock-ModuleVariable -Name 'requested'

# Assert
Assert-Equal -Expected 'VariableNotWritable,Format-Tally' -Actual $format.Id `
    -Message 'A failure before Format-Tally has read its names is raised, not skipped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the step of Read-Tally that reads a part, made to fail
Lock-ModuleVariable -Name 'Matches'

# Act
$read = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock {
    param($action)
    Read-Tally -Text '3 passed' -ErrorAction $action
}
Unlock-ModuleVariable -Name 'Matches'

# Assert
Assert-Equal -Expected 'VariableNotWritable,Read-Tally' -Actual $read.Id `
    -Message 'A failure while Read-Tally reads a part is raised, not skipped'
Assert-Equal -Expected 0 -Actual $read.Output -Message 'and nothing is written'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a plain script, with no try or catch, that adds three names, the second not a valid one, under
# -ErrorAction SilentlyContinue, which is where a plain throw is skipped and the command carries on
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1'
$script = @"
Import-Module '$modulePath'
Clear-Tally
'first', ' bad', 'third' | Add-Tally -ErrorAction SilentlyContinue
Format-Tally -Name 'first', 'third'
"@

# Act
$run = @(& pwsh -NoProfile -NonInteractive -Command $script 2>&1 | ForEach-Object { "$_" })

# Assert
Assert-That -Condition ($run -contains '1 first - 0 third') `
    -Message 'A plain script is not carried past the name that cannot be counted, even under SilentlyContinue'
Assert-That -Condition (($run -join ' ') -like "*' bad' is not a valid tally name*") `
    -Message 'and the error is reported, not swallowed'

exit (Complete-TestRun)
