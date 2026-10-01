#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')
$module = Get-Module TaffarelJr.UserInput

# The User settings are a stand-in, so nothing here changes the real ones;
# this process's own variables are real, and their names are unique.
Use-FakeEnvironmentStore -Module $module
$varName = "TAFFARELJR_USERINPUT_WHATIF_$([Guid]::NewGuid().ToString('N'))"
$otherName = "TAFFARELJR_USERINPUT_WHATIF_$([Guid]::NewGuid().ToString('N'))"
$unixName = "TAFFARELJR_USERINPUT_WHATIF_$([Guid]::NewGuid().ToString('N'))"
$set = 'What if: Performing the operation "Set environment variable" on target'
$remove = 'What if: Performing the operation "Remove environment variable" on target'

function Set-ThroughWrapper {
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'Set-EnvironmentVariable asks ShouldProcess; the test needs this -WhatIf to reach it.')]
    param()

    Set-EnvironmentVariable -Name $varName -Value 'top-secret-value'
}

# $IsWindows is forced, so both platforms' behavior is tested here. It is
# read-only, hence -Force, and it is put back however the cases end.
$originalIsWindows = $IsWindows
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Variable -Name IsWindows -Value $true -Force -Scope Global

    # Act
    $run = Get-WhatIfOutput { Set-EnvironmentVariable -Name $varName -Value 'top-secret-value' -WhatIf }

    # Assert
    Assert-Equal -Expected $null -Actual (Get-FakeStoredValue -Module $module -Name $varName -Target User) `
        -Message '-WhatIf saves nothing in the User settings'
    Assert-Equal -Expected $null -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'and sets nothing in this process'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("$set ""$varName (User)"".", "$set ""$varName (Process)"".") -Actual $run.Messages `
        -Message '-WhatIf names the variable and each scope it would write, and never the value'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a caller of the function that was itself given -WhatIf
    $run = Get-WhatIfOutput { Set-ThroughWrapper -WhatIf }

    # Assert
    Assert-Equal -Expected $null -Actual (Get-FakeStoredValue -Module $module -Name $varName -Target User) `
        -Message 'A caller''s -WhatIf reaches the function: nothing is saved in the User settings'
    Assert-Equal -Expected $null -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'and nothing is set in this process'
    Assert-Equal -Expected @("$set ""$varName (User)"".", "$set ""$varName (Process)"".") -Actual $run.Messages `
        -Message 'and each scope it would have written is named'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two objects for the pipeline
    $two = @(
        [PSCustomObject]@{ Name = $varName; Value = 'a' }
        [PSCustomObject]@{ Name = $otherName; Value = 'b' }
    )

    # Act
    $run = Get-WhatIfOutput { $two | Set-EnvironmentVariable -WhatIf }

    # Assert
    Assert-Equal -Expected $null -Actual (Get-FakeStoredValue -Module $module -Name $otherName -Target User) `
        -Message '-WhatIf saves neither piped variable'
    Assert-Equal -Expected $null -Actual ([Environment]::GetEnvironmentVariable($otherName)) `
        -Message 'and sets neither in this process'
    Assert-Equal -Expected @(
        "$set ""$varName (User)""."
        "$set ""$varName (Process)""."
        "$set ""$otherName (User)""."
        "$set ""$otherName (Process)""."
    ) -Actual $run.Messages -Message 'and names each of them, in each scope'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a saved variable, and an empty value that would remove it
    Set-FakeStoredValue -Module $module -Name $varName -Value 'kept' -Target User
    [Environment]::SetEnvironmentVariable($varName, 'kept')

    # Act
    $run = Get-WhatIfOutput { '' | Set-EnvironmentVariable -Name $varName -WhatIf }

    # Assert
    Assert-Equal -Expected 'kept' -Actual (Get-FakeStoredValue -Module $module -Name $varName -Target User) `
        -Message '-WhatIf with an empty piped value removes nothing from the User settings'
    Assert-Equal -Expected 'kept' -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'nor from this process'
    Assert-Equal -Expected @("$remove ""$varName (User)"".", "$remove ""$varName (Process)"".") -Actual $run.Messages `
        -Message 'and says it would remove it, in each scope'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Variable -Name IsWindows -Value $false -Force -Scope Global

    # Act
    $lines = @(Get-HostOutput { Set-EnvironmentVariable -Name $otherName -Value 'x' -WhatIf })

    # Assert
    Assert-Equal -Expected @() -Actual $lines `
        -Message 'On a non-Windows platform, -WhatIf prints no reminder, since nothing was set'
    Assert-Equal -Expected $null -Actual ([Environment]::GetEnvironmentVariable($otherName)) -Message 'and sets nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Variable -Name IsWindows -Value $false -Force -Scope Global

    # Act
    $run = Get-WhatIfOutput { Set-EnvironmentVariable -Name $otherName -Value 'x' -WhatIf 6>$null }

    # Assert
    Assert-Equal -Expected @("$set ""$otherName (Process)"".") -Actual $run.Messages `
        -Message 'On a non-Windows platform, -WhatIf names only the Process scope: nothing is written to User there'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Variable -Name IsWindows -Value $false -Force -Scope Global

    # Act
    $null = Get-HostOutput { Set-EnvironmentVariable -Name $unixName -Value 'x' }

    # Assert
    Assert-Equal -Expected $null -Actual (Get-FakeStoredValue -Module $module -Name $unixName -Target User) `
        -Message 'and without -WhatIf the User step is not taken at all there'
    Assert-Equal -Expected 'x' -Actual ([Environment]::GetEnvironmentVariable($unixName)) `
        -Message 'while this process still gets the value'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Set-EnvironmentVariable -Name 'A=B' -Value 'x' -WhatIf } `
        -MessageLike "*Environment variable name 'A=B' must not be blank, start with a space, or contain '='" `
        -Message '-WhatIf still refuses a name that cannot be an environment variable'
}
finally {
    Set-Variable -Name IsWindows -Value $originalIsWindows -Force -Scope Global
    [Environment]::SetEnvironmentVariable($varName, $null)
    [Environment]::SetEnvironmentVariable($otherName, $null)
    [Environment]::SetEnvironmentVariable($unixName, $null)
}

exit (Complete-TestRun)
