#Requires -Version 7.4
using namespace System.Management.Automation

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Read by the script block or child process the test hands it to, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

$modulePath = Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1'
$probeScript = @(
    "Import-Module '<module>'"
    'function Set-Probe {'
    '    [CmdletBinding(SupportsShouldProcess)]'
    '    param([string]$Name)'
    '    if ($PSCmdlet.ShouldProcess($Name, ''Set probe'')) { "set $Name" }'
    '}'
    'function Invoke-Probe {'
    '    [CmdletBinding(SupportsShouldProcess)]'
    '    param()'
    '    Invoke-Doing -Text ''Probing'' -ScriptBlock { Set-Probe -Name ''alpha'' }'
    '}'
    '<call>'
) -join "`n"
$successMarker = "$([char]0x2705) "
$infoMarker = "$([char]0x2139)$([char]0xFE0F)  "

function Get-Display {
    <#
    .SYNOPSIS
        Runs a script block and returns what it printed to the host and
        wrote as warnings, in the order it happened.
    .DESCRIPTION
        Not exported - a test-only fixture. A warning's text starts with
        "warning: ".
    .PARAMETER ScriptBlock
        The code to run and watch.
    .OUTPUTS
        One object per host call or warning - Text and Color - one at a
        time. Wrap the call in @() to collect them as an array.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $records = & $ScriptBlock 3>&1 6>&1
    foreach ($record in $records) {
        if ($record -is [WarningRecord]) {
            [PSCustomObject]@{ Text = "warning: $($record.Message)"; Color = '' }
        }
        elseif ($record -is [InformationRecord] -and $record.MessageData -is [HostInformationMessage]) {
            [PSCustomObject]@{ Text = $record.MessageData.Message; Color = "$($record.MessageData.ForegroundColor)" }
        }
    }
}

function Get-ProbeLine {
    <#
    .SYNOPSIS
        Runs Invoke-Doing around a command that supports -WhatIf in a new
        PowerShell, and returns the lines it printed that matter, in order.
    .DESCRIPTION
        Not exported - a test-only fixture. The 'What if:' lines of
        ShouldProcess go to the host on no stream, so only the output of a
        process of its own shows them in the order they were printed
        alongside the lines this module writes. A line of this module's own
        comes back from its text on, so the marker, which depends on the
        console's encoding, is left out.
    .PARAMETER Preview
        Calls the function that holds the block with -WhatIf.
    .OUTPUTS
        System.String. The 'What if:' lines and the Doing line, one at a
        time. Wrap the call in @() to collect them as an array.
    #>
    param(
        [switch]$Preview
    )

    $call = if ($Preview) { 'Invoke-Probe -WhatIf' } else { 'Invoke-Probe' }
    $script = $probeScript.Replace('<module>', $modulePath).Replace('<call>', $call)
    foreach ($line in @(& pwsh -NoProfile -NonInteractive -Command $script)) {
        if ($line.StartsWith('What if:')) {
            $line
        }
        elseif ($line.Contains('Probing')) {
            $line.Substring($line.IndexOf('Probing'))
        }
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a block that returns nothing
$shown = @(Get-Display { Invoke-Doing -Text 'building' -ScriptBlock { } })

# Assert
Assert-Equal -Expected @('  ▶ building ...', ' done') -Actual @($shown.Text) `
    -Message 'The line is opened, then closed with "done" when the block returns nothing'
Assert-Equal -Expected @('Cyan', 'Green') -Actual @($shown.Color) -Message 'in cyan, then green'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a block whose last output is a string
$shown = @(Get-Display { Invoke-Doing -Text 'installing' -ScriptBlock { 'installed 3 packages' } })
$output = @(Invoke-Doing -Text 'installing' -ScriptBlock { 'installed 3 packages' } 6>$null)

# Assert
Assert-Equal -Expected @('  ▶ installing ...', ' installed 3 packages') -Actual @($shown.Text) `
    -Message 'The string the block returns closes the line'
Assert-Equal -Expected @() -Actual $output -Message 'and is not written to the pipeline as well'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a block that writes several things
$shown = @(Get-Display { Invoke-Doing -Text 'working' -ScriptBlock { 'one'; 'two'; 'three' } })
$output = @(Invoke-Doing -Text 'working' -ScriptBlock { 'one'; 'two'; 'three' } 6>$null)

# Assert
Assert-Equal -Expected @('  ▶ working ...', ' three') -Actual @($shown.Text) `
    -Message 'Only the last thing the block returns closes the line'
Assert-Equal -Expected @('one', 'two') -Actual $output -Message 'and the others are written to the pipeline, in order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a block whose last output is not text
$shown = @(Get-Display { Invoke-Doing -Text 'counting' -ScriptBlock { 42 } })
$output = @(Invoke-Doing -Text 'counting' -ScriptBlock { 42 } 6>$null)

# Assert
Assert-Equal -Expected @('  ▶ counting ...', ' done') -Actual @($shown.Text) `
    -Message 'A last output that is not a string is not read as the outcome'
Assert-Equal -Expected @(42) -Actual $output -Message 'and is written to the pipeline'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
$assigned = 'before'

# Act - the block runs in the caller's own scope
$null = Invoke-Doing -Text 'assigning' -ScriptBlock { $assigned = 'inside' } 6>$null

# Assert
Assert-Equal -Expected 'inside' -Actual $assigned `
    -Message 'A variable the block assigns is the caller''s variable, as with ForEach-Object'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a block that warns while the line is open
$shown = @(Get-Display {
        Invoke-Doing -Text 'building' -ScriptBlock {
            Write-Warning 'careful'
            Write-Warning 'very careful'
            'ok'
        }
    })

# Assert
Assert-Equal -Expected @('  ▶ building ...', ' ok', 'warning: careful', 'warning: very careful') `
    -Actual @($shown.Text) `
    -Message 'Warnings the block writes wait until the line is closed, and come out in order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a block that throws
$shown = @(Get-Display {
        try {
            Invoke-Doing -Text 'building' -ScriptBlock { throw 'boom' }
        }
        catch {
            $null = $_
        }
    })

# Assert
Assert-Equal -Expected @('  ▶ building ...', ' failed') -Actual @($shown.Text) `
    -Message 'A block that throws closes the line with "failed"'
Assert-Equal -Expected @('Cyan', 'Red') -Actual @($shown.Color) -Message 'in red'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act / Assert - the block throws
Assert-Throws -ScriptBlock {
    Invoke-Doing -Text 'building' -ScriptBlock { throw [IO.FileNotFoundException]::new('boom from the block') } 6>$null
} -MessageLike 'boom from the block' -ExceptionType ([IO.FileNotFoundException]) `
    -Message 'The exception the block threw is raised again, as it was thrown'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a block that warns, then throws
$shown = @(Get-Display {
        try {
            Invoke-Doing -Text 'building' -ScriptBlock { Write-Warning 'careful'; throw 'boom' }
        }
        catch {
            $null = $_
        }
    })

# Assert
Assert-Equal -Expected @('  ▶ building ...', ' failed', 'warning: careful') -Actual @($shown.Text) `
    -Message 'A warning written before the throw is still shown, after the closed line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a block that prints with this module's own writers, which close the open line
$shown = @(Get-Display { Invoke-Doing -Text 'building' -ScriptBlock { Write-Info 'inside'; 'ok' } })

# Assert
Assert-Equal -Expected @('  ▶ building ...', '', "  ${infoMarker}inside", "  ${successMarker}ok") `
    -Actual @($shown.Text) `
    -Message 'A line the block closed is not closed twice: the outcome prints as a line of its own'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
$whatIfLine = 'What if: Performing the operation "Set probe" on target "alpha".'

# Act - the session previews every change, so the block's own command says what it would do
$lines = @(Get-ProbeLine -Preview)

# Assert
Assert-Equal -Expected @($whatIfLine, 'Probing ... done') -Actual $lines `
    -Message 'Under -WhatIf the line is printed after the What if: lines of the block, whole'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - the same call with nothing previewed
$lines = @(Get-ProbeLine)

# Assert
Assert-Equal -Expected @('Probing ... set alpha') -Actual $lines `
    -Message 'Without -WhatIf the line is opened before the block runs, and closed with what the block returned'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a previewed block that throws
$shown = @(Get-Display {
        try {
            $WhatIfPreference = $true
            Invoke-Doing -Text 'building' -ScriptBlock { throw 'boom' }
        }
        catch {
            $null = $_
        }
    })

# Assert
Assert-Equal -Expected @('  ▶ building ...', ' failed') -Actual @($shown.Text) `
    -Message 'Under -WhatIf a block that throws still gets its line, closed with "failed"'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act
$null = Get-Display { Invoke-Doing -Text 'x' -ScriptBlock { } }
$openAfterSuccess = & $module { $script:LineOpen }
$null = Get-Display { try { Invoke-Doing -Text 'x' -ScriptBlock { throw 'boom' } } catch { $null = $_ } }
$openAfterFailure = & $module { $script:LineOpen }

# Assert
Assert-That -Condition (-not $openAfterSuccess) -Message 'A finished call leaves no line open'
Assert-That -Condition (-not $openAfterFailure) -Message 'and neither does one whose block threw'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Invoke-Doing -Text 'x' -ScriptBlock $null } -MessageLike '*ScriptBlock*' `
    -Message 'A $null script block is refused'

exit (Complete-TestRun)
