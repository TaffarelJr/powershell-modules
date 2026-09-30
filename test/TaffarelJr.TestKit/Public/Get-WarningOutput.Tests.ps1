#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Reports a test result to the person at the console; it is not data.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$warnings = @(Get-WarningOutput { Write-Warning 'first'; Write-Warning 'second' })

# Assert
Assert-Equal -Expected @('first', 'second') -Actual $warnings -Message 'Each warning is captured as its text, in order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$none = @(Get-WarningOutput { $null = 1 + 1 })
$bare = Get-WarningOutput { $null = 1 + 1 }

# Assert
Assert-Equal -Expected @() -Actual $none `
    -Message 'A block that warns about nothing writes nothing, so @() collects an empty array'
Assert-That -Condition ($null -eq $bare) -Message 'and a bare capture is $null'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - one warning, and two piped straight on
$one = Get-WarningOutput { Write-Warning 'only' }
$piped = Get-WarningOutput { Write-Warning 'first'; Write-Warning 'second' } | Measure-Object

# Assert
Assert-Equal -Expected 'only' -Actual $one -Message 'A single warning comes back as that text'
Assert-Equal -Expected 2 -Actual $piped.Count `
    -Message 'Each warning is its own pipeline item, so the result pipes straight on'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - other output alongside the warning
$mixed = @(Get-WarningOutput { Write-Host 'printed'; 'returned'; Write-Warning 'careful' } 6>$null)

# Assert
Assert-Equal -Expected @('careful') -Actual $mixed -Message 'Only the warning is captured, not host or pipeline output'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - warnings silenced or made fatal, in the caller's scope and globally
$warner = New-Module -Name WarningOutputProbe -ScriptBlock {
    function Write-ProbeWarning {
        Write-Warning 'from a module'
    }
}
function Get-CapturedUnder {
    param(
        [string]$Preference
    )

    $globalBefore = $global:WarningPreference
    $WarningPreference = $Preference
    $global:WarningPreference = $Preference
    try {
        @(Get-WarningOutput { Write-Warning 'from the block'; Write-ProbeWarning })
        "after: $WarningPreference, $global:WarningPreference"
    }
    finally {
        $global:WarningPreference = $globalBefore
    }
}

# Act
$silenced = @(Get-CapturedUnder -Preference 'SilentlyContinue')
$fatal = @(Get-CapturedUnder -Preference 'Stop')
Remove-Module $warner

# Assert
Assert-Equal -Expected @('from the block', 'from a module', 'after: SilentlyContinue, SilentlyContinue') `
    -Actual $silenced `
    -Message 'Silenced warnings are still captured, from the block and from a module, and the preference is put back'
Assert-Equal -Expected @('from the block', 'from a module', 'after: Stop, Stop') -Actual $fatal `
    -Message 'Warnings that would stop the caller are captured instead, and the preference is put back'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - callers with no preference of their own, then a global change
$captureThenSilenceGlobally = {
    $null = Get-WarningOutput { Write-Warning 'captured' }
    [bool](Get-Variable -Name WarningPreference -Scope Local -ErrorAction Ignore)
    $globalBefore = $global:WarningPreference
    $global:WarningPreference = 'SilentlyContinue'
    try {
        "$WarningPreference"
    }
    finally {
        $global:WarningPreference = $globalBefore
    }
}
function Get-PlainCallerState {
    . $captureThenSilenceGlobally
}
function Get-AdvancedCallerState {
    [CmdletBinding()]
    param()

    . $captureThenSilenceGlobally
}

# Act
$plain = @(Get-PlainCallerState)
$advanced = @(Get-AdvancedCallerState)

# Assert
Assert-Equal -Expected @($false, 'SilentlyContinue') -Actual $plain `
    -Message 'A function with no preference of its own is left without one, so a later global change still reaches it'
Assert-Equal -Expected @($false, 'SilentlyContinue') -Actual $advanced -Message 'and so is an advanced function'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a preference set by an outer function, read by an inner one
function Get-InnerCallerState {
    $null = Get-WarningOutput { Write-Warning 'captured' }
    [bool](Get-Variable -Name WarningPreference -Scope Local -ErrorAction Ignore)
}
function Get-OuterCallerState {
    $WarningPreference = 'Stop'
    Get-InnerCallerState
    "$WarningPreference"
}

# Act
$nested = @(Get-OuterCallerState)

# Assert
Assert-Equal -Expected @($false, 'Stop') -Actual $nested `
    -Message 'A preference inherited from an outer function is put back where it lives, not copied into the inner one'

exit (Complete-TestRun)
