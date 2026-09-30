#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

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
        many objects it wrote, and the lines it printed to the host, joined by a bar.
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
        Printed  = (@($printed | ForEach-Object { $_.MessageData.Message }) -join '|')
    }
}

function Enable-HelperFailure {
    <#
    .SYNOPSIS
        Makes one of the module's private functions fail, or do something
        else the test needs.
    .DESCRIPTION
        Not exported - a test-only fixture, for a command that has no failing
        input to give. Returns what Disable-HelperFailure needs to put the
        function back.
    .PARAMETER Name
        The private function that fails.
    .PARAMETER Body
        The function's replacement body. Throws 'helper failed' when left
        out.
    .OUTPUTS
        The function's own script block.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Body = "throw 'helper failed'"
    )

    $original = & $module {
        param($name)
        (Get-Command -Name $name -CommandType Function).ScriptBlock
    } $Name
    & $module {
        param($name, $text)
        $replacement = [scriptblock]::Create($text)
        Set-Item -Path "function:script:$name" -Value $replacement
    } $Name $Body
    return $original
}

function Disable-HelperFailure {
    <#
    .SYNOPSIS
        Puts back a private function Enable-HelperFailure replaced.
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

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a block that throws
Reset-ConsoleOutputState -Module $module

# Act - Invoke-Indented
$outcomes = foreach ($preference in $preferences) {
    [PSCustomObject]@{
        Outcome = Get-ErrorOutcome -Preference $preference -ScriptBlock {
            param($action)
            Invoke-Indented { throw 'block failed' } -ErrorAction $action
        }
        Indent  = Get-Indent
    }
}

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Outcome.Raised) `
    -Message 'A block that throws is raised by Invoke-Indented whatever -ErrorAction says'
Assert-Equal -Expected @(0, 0, 0, 0) -Actual @($outcomes.Indent) `
    -Message 'and the indent is put back where it was'
Assert-Equal -Expected @('RuntimeException,Invoke-Indented', 'RuntimeException,Invoke-Indented',
    'RuntimeException,Invoke-Indented', 'RuntimeException,Invoke-Indented') -Actual @($outcomes.Outcome.Id) `
    -Message 'The error ID names the kind of failure and the command'
Assert-Equal -Expected @('InvalidOperation', 'InvalidOperation', 'InvalidOperation', 'InvalidOperation') `
    -Actual @($outcomes.Outcome.Category) -Message 'and the category is an invalid operation'
Assert-Equal -Expected @('block failed', 'block failed', 'block failed', 'block failed') `
    -Actual @($outcomes.Outcome.Target) -Message 'and the target is what was thrown'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a block that throws
Reset-ConsoleOutputState -Module $module

# Act - Invoke-Doing
$outcomes = foreach ($preference in $preferences) {
    [PSCustomObject]@{
        Outcome = Get-ErrorOutcome -Preference $preference -ScriptBlock {
            param($action)
            Invoke-Doing -Text 'building' -ScriptBlock { throw 'block failed' } -ErrorAction $action
        }
        Open    = & $module { $script:LineOpen }
    }
}

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Outcome.Raised) `
    -Message 'A block that throws is raised by Invoke-Doing whatever -ErrorAction says'
Assert-Equal -Expected @($false, $false, $false, $false) -Actual @($outcomes.Open) `
    -Message 'and the line it opened is closed'
Assert-Equal -Expected @('RuntimeException,Invoke-Doing', 'RuntimeException,Invoke-Doing',
    'RuntimeException,Invoke-Doing', 'RuntimeException,Invoke-Doing') -Actual @($outcomes.Outcome.Id) `
    -Message 'The error ID names the kind of failure and the command'
Assert-Equal -Expected @('InvalidOperation', 'InvalidOperation', 'InvalidOperation', 'InvalidOperation') `
    -Actual @($outcomes.Outcome.Category) -Message 'and the category is an invalid operation'
Assert-Equal -Expected @('block failed', 'block failed', 'block failed', 'block failed') `
    -Actual @($outcomes.Outcome.Target) -Message 'and the target is what was thrown'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a printer that fails on the second of three lines
$original = Enable-HelperFailure -Name 'Write-MarkerLine' -Body @'
param($Text, $Marker, $Color, $Indent)
if ($Text -eq 'second') { throw 'second failed' }
Write-Host "printed $Text"
'@

# Act - Write-Info, piped three lines
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        'first', 'second', 'third' | Write-Info -ErrorAction $action
    }
}
Disable-HelperFailure -Name 'Write-MarkerLine' -Original $original

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A line that cannot be printed raises an error whatever -ErrorAction says'
Assert-Equal -Expected @('printed first', 'printed first', 'printed first', 'printed first') `
    -Actual @($outcomes.Printed) `
    -Message 'and stops the pipeline: the line before it is printed, the one after it is not'
Assert-Equal -Expected @('RuntimeException,Write-Info', 'RuntimeException,Write-Info',
    'RuntimeException,Write-Info', 'RuntimeException,Write-Info') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'
Assert-Equal -Expected @('second failed', 'second failed', 'second failed', 'second failed') `
    -Actual @($outcomes.Target) -Message 'with what was thrown as the target'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a box that cannot be drawn for the second of three texts
$original = Enable-HelperFailure -Name 'Write-Box' -Body @'
param($Text, $Trim, $Bordered)
if ($Text -eq 'second') { throw 'second failed' }
Write-Host "boxed $Text"
'@

# Act - Write-Header, piped three texts
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        'first', 'second', 'third' | Write-Header -ErrorAction $action
    }
}
Disable-HelperFailure -Name 'Write-Box' -Original $original

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A header that cannot be drawn raises an error whatever -ErrorAction says'
Assert-Equal -Expected @('boxed first', 'boxed first', 'boxed first', 'boxed first') -Actual @($outcomes.Printed) `
    -Message 'and stops the pipeline'
Assert-Equal -Expected @('RuntimeException,Write-Header', 'RuntimeException,Write-Header',
    'RuntimeException,Write-Header', 'RuntimeException,Write-Header') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a field that cannot be printed for the second of three objects
$original = Enable-HelperFailure -Name 'Write-MessageLine' -Body @'
param($Lead, $Continuation, $Text, $Color)
if ($Lead -like '*second*') { throw 'second failed' }
Write-Host "field $Text"
'@
$records = 'first', 'second', 'third' | ForEach-Object { [PSCustomObject]@{ Name = $_; Value = "v-$_" } }

# Act - Write-Field, piped three objects
$outcomes = foreach ($preference in $preferences) {
    Get-ErrorOutcome -Preference $preference -ScriptBlock {
        param($action)
        $records | Write-Field -ErrorAction $action
    }
}
Disable-HelperFailure -Name 'Write-MessageLine' -Original $original

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($outcomes.Raised) `
    -Message 'A field that cannot be printed raises an error whatever -ErrorAction says'
Assert-Equal -Expected @('field v-first', 'field v-first', 'field v-first', 'field v-first') `
    -Actual @($outcomes.Printed) -Message 'and stops the pipeline'
Assert-Equal -Expected @('RuntimeException,Write-Field', 'RuntimeException,Write-Field',
    'RuntimeException,Write-Field', 'RuntimeException,Write-Field') -Actual @($outcomes.Id) `
    -Message 'under the command''s error ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every other command, with the private function it relies on made to fail
Reset-ConsoleOutputState -Module $module
$cases = @(
    @{ Command = 'Clear-Step'; Helper = 'Close-OpenLine'; Call = { param($a) Clear-Step -ErrorAction $a } }
    @{ Command = 'Write-Banner'; Helper = 'Write-Box'; Call = { param($a) Write-Banner 'x' -ErrorAction $a } }
    @{ Command = 'Write-Detail'; Helper = 'Write-MarkerLine'; Call = { param($a) Write-Detail 'x' -ErrorAction $a } }
    @{ Command = 'Write-Doing'; Helper = 'Close-OpenLine'; Call = { param($a) Write-Doing 'x' -ErrorAction $a } }
    @{ Command = 'Write-Failure'; Helper = 'Write-MarkerLine'; Call = { param($a) Write-Failure 'x' -ErrorAction $a } }
    @{ Command = 'Write-Skip'; Helper = 'Write-MarkerLine'; Call = { param($a) Write-Skip 'x' -ErrorAction $a } }
    @{ Command = 'Write-Step'; Helper = 'Format-MessageText'; Call = { param($a) Write-Step 'x' -ErrorAction $a } }
    @{ Command = 'Write-Success'; Helper = 'Write-MarkerLine'; Call = { param($a) Write-Success 'x' -ErrorAction $a } }
    @{ Command = 'Write-Warn'; Helper = 'Write-MarkerLine'; Call = { param($a) Write-Warn 'x' -ErrorAction $a } }
)

# Act
$outcomes = foreach ($case in $cases) {
    $original = Enable-HelperFailure -Name $case.Helper
    $outcome = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock $case.Call
    Disable-HelperFailure -Name $case.Helper -Original $original
    $outcome
}

# Assert
Assert-Equal -Expected @($cases.ForEach('Command') | ForEach-Object { "RuntimeException,$_" }) `
    -Actual @($outcomes.Id) -Message 'A failure inside any printer is raised under that printer''s own error ID'
Assert-Equal -Expected @($cases.ForEach({ '' })) -Actual @($outcomes.Printed) `
    -Message 'and nothing is printed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an open line, and the step that closes it made to fail
Reset-ConsoleOutputState -Module $module
& $module { $script:LineOpen = $true }
$original = Enable-HelperFailure -Name 'Format-MessageText'

# Act - Write-Done
$done = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock {
    param($action)
    Write-Done 'finished' -ErrorAction $action
}
Disable-HelperFailure -Name 'Format-MessageText' -Original $original
Reset-ConsoleOutputState -Module $module

# Assert
Assert-Equal -Expected 'RuntimeException,Write-Done' -Actual $done.Id `
    -Message 'A failure while Write-Done closes the open line is raised under its own error ID'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a header that cannot be drawn
$original = Enable-HelperFailure -Name 'Write-Box'

# Act - Write-Banner and Write-Header
$banner = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock {
    param($action)
    Write-Banner 'x' -ErrorAction $action
}
$header = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock {
    param($action)
    Write-Header 'x' -ErrorAction $action
}
Disable-HelperFailure -Name 'Write-Box' -Original $original

# Assert
Assert-Equal -Expected 'RuntimeException,Write-Banner' -Actual $banner.Id `
    -Message 'A banner that cannot be drawn is raised under its own error ID'
Assert-Equal -Expected 'RuntimeException,Write-Header' -Actual $header.Id `
    -Message 'and so is a header'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the state each command reads, taken away
$stateCases = @(
    @{
        Command  = 'Get-CurrentStep'
        Variable = 'CurrentStepLabel'
        Call     = { param($a) Get-CurrentStep -ErrorAction $a }
    }
    @{ Command = 'Get-Indent'; Variable = 'IndentStack'; Call = { param($a) Get-Indent -ErrorAction $a } }
    @{ Command = 'Pop-Indent'; Variable = 'IndentStack'; Call = { param($a) Pop-Indent -ErrorAction $a } }
    @{ Command = 'Push-Indent'; Variable = 'IndentStack'; Call = { param($a) Push-Indent -ErrorAction $a } }
)

# Act
$outcomes = foreach ($case in $stateCases) {
    $value = & $module {
        param($name)
        $held = (Get-Variable -Name $name -Scope Script).Value
        Remove-Variable -Name $name -Scope Script
        $held
    } $case.Variable
    $outcome = Get-ErrorOutcome -Preference 'SilentlyContinue' -ScriptBlock $case.Call
    & $module {
        param($name, $held)
        Set-Variable -Name $name -Scope Script -Value $held
    } $case.Variable $value
    $outcome
}

# Assert
Assert-Equal -Expected @($stateCases.ForEach('Command') | ForEach-Object { "VariableIsUndefined,$_" }) `
    -Actual @($outcomes.Id) -Message 'State that is missing is raised under the reading command''s own error ID'
Assert-Equal -Expected @($stateCases.ForEach({ 'InvalidOperation' })) -Actual @($outcomes.Category) `
    -Message 'as an invalid operation'
Assert-Equal -Expected @($stateCases.ForEach({ 0 })) -Actual @($outcomes.Output) -Message 'and nothing is returned'

exit (Complete-TestRun)
