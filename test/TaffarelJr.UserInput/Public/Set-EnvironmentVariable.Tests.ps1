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
# this process's own variable is real, and its name is unique.
Use-FakeEnvironmentStore -Module $module
$varName = "TAFFARELJR_USERINPUT_TEST_$([Guid]::NewGuid().ToString('N'))"

# $IsWindows is forced, so both platforms' behavior is tested here. It is
# read-only, hence -Force, and it is put back however the cases end.
$originalIsWindows = $IsWindows
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Variable -Name IsWindows -Value $true -Force -Scope Global

    # Act
    $lines = @(Get-HostOutput { Set-EnvironmentVariable -Name $varName -Value 'written' })

    # Assert
    Assert-Equal -Expected 'written' -Actual (Get-FakeStoredValue -Module $module -Name $varName -Target User) `
        -Message 'Writes to the User settings, so a later run can find it'
    Assert-Equal -Expected 'written' -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'Also writes to the current process, so this run sees it without restarting'
    Assert-Equal -Expected 0 -Actual $lines.Count -Message 'On Windows, persistence is silent - no reminder is printed'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the value can be piped in, with -Name given explicitly
    'piped-value' | Set-EnvironmentVariable -Name $varName

    # Assert
    Assert-Equal -Expected 'piped-value' -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'The value binds from the pipeline'
    Assert-Equal -Expected 'piped-value' -Actual (Get-FakeStoredValue -Module $module -Name $varName -Target User) `
        -Message 'and is saved too'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an object with Name and Value properties
    [PSCustomObject]@{ Name = $varName; Value = 'from-an-object' } | Set-EnvironmentVariable

    # Assert
    Assert-Equal -Expected 'from-an-object' -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'Both the name and the value bind from the properties of a piped object'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an object whose Value is a number, and a number given directly
    [PSCustomObject]@{ Name = $varName; Value = 42 } | Set-EnvironmentVariable
    $fromObject = [Environment]::GetEnvironmentVariable($varName)
    $fromObjectSaved = Get-FakeStoredValue -Module $module -Name $varName -Target User
    Set-EnvironmentVariable -Name $varName -Value 8080

    # Assert
    Assert-Equal -Expected '42' -Actual $fromObject `
        -Message 'An object whose Value is a number writes that number as text'
    Assert-Equal -Expected '42' -Actual $fromObjectSaved -Message 'and saves it so'
    Assert-Equal -Expected '8080' -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'A number given as the value is written as text too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a variable that must survive the calls that are refused
    Set-EnvironmentVariable -Name $varName -Value 'kept'
    $noValue = { [PSCustomObject]@{ Name = $varName; Other = 'x' } | Set-EnvironmentVariable }
    $aDate = { Set-EnvironmentVariable -Name $varName -Value ([datetime]::Now) }
    $pattern = "*Cannot read an environment variable's value from a $([WildcardPattern]::Escape('[PSCustomObject]'))*"

    # Act / Assert
    Assert-Throws -ScriptBlock $noValue -MessageLike $pattern `
        -Message 'An object with no Value property is refused, naming what it was'
    Assert-Throws -ScriptBlock $aDate -MessageLike "*from a $([WildcardPattern]::Escape('[DateTime]'))*" `
        -Message 'and so is a date, which has none'
    Assert-Equal -Expected 'kept' -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'and nothing is written when one is refused'
    Assert-Equal -Expected 'kept' -Actual (Get-FakeStoredValue -Module $module -Name $varName -Target User) `
        -Message 'in either place'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an object whose Value is empty, and $null
    [PSCustomObject]@{ Name = $varName; Value = $null } | Set-EnvironmentVariable
    $afterNullProperty = [Environment]::GetEnvironmentVariable($varName)
    Set-EnvironmentVariable -Name $varName -Value 'kept again'
    Set-EnvironmentVariable -Name $varName -Value $null
    $afterNull = [Environment]::GetEnvironmentVariable($varName)

    # Assert
    Assert-Equal -Expected $null -Actual $afterNullProperty `
        -Message 'An object whose Value is $null removes the variable, as an empty value does'
    Assert-Equal -Expected $null -Actual $afterNull -Message 'and so does a $null value'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an empty value
    Set-EnvironmentVariable -Name $varName -Value ''

    # Assert
    Assert-Equal -Expected $null -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'An empty value removes the variable from this process'
    Assert-Equal -Expected $null -Actual (Get-FakeStoredValue -Module $module -Name $varName -Target User) `
        -Message 'and from the User settings'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Variable -Name IsWindows -Value $false -Force -Scope Global

    # Act
    $lines = @(Get-HostOutput { Set-EnvironmentVariable -Name $varName -Value 'top-secret-value' })

    # Assert
    Assert-Equal -Expected 3 -Actual $lines.Count `
        -Message 'On a non-Windows platform, a reminder prints instead of silently doing less'
    Assert-That -Condition ($lines -join "`n").Contains($varName) -Message 'The reminder names the variable to export'
    Assert-That -Condition (-not ($lines -join "`n").Contains('top-secret-value')) `
        -Message 'The reminder never echoes the value itself, secret or not'
}
finally {
    Set-Variable -Name IsWindows -Value $originalIsWindows -Force -Scope Global
    [Environment]::SetEnvironmentVariable($varName, $null)
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names that cannot be an environment variable
$badNames = @(
    @{ Name = 'only spaces'; Value = '   ' }
    @{ Name = 'a leading space'; Value = ' NAME' }
    @{ Name = 'an equals sign'; Value = 'A=B' }
    @{ Name = 'a leading equals sign'; Value = '=A' }
)

foreach ($bad in $badNames) {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-EnvironmentVariable -Name $bad.Value -Value 'x'
    } -MessageLike "*Environment variable name '$($bad.Value)' must not be blank, start with a space, or contain '='" `
        -Message "A name with $($bad.Name) is refused"
    Assert-Equal -Expected $null -Actual (Get-FakeStoredValue -Module $module -Name $bad.Value -Target User) `
        -Message 'before anything is saved'
}

# The guard's own cases below cannot write anything, even if a later case
# calls into them: every module is imported with -Function @(), so none of
# its commands can be called by name from here; the stand-in goes in right
# after each import that allows it; the one unfaked module is removed as soon
# as it has been checked; and a doctored function only holds a writer's text
# in a string it throws away.
$manifest = Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$unfaked = Import-Module $manifest -Force -PassThru -Function @()

# Act
$exported = Get-Command -Name Set-EnvironmentVariable -ErrorAction Ignore
$unfakedError = Get-ThrownError { Assert-FakeEnvironmentStore -Module $unfaked }
Remove-Module -ModuleInfo $unfaked -Force
$leftLoaded = @(Get-Module -Name TaffarelJr.UserInput)

# Assert
Assert-Equal -Expected $null -Actual $exported `
    -Message 'A module imported for the guard''s cases puts no writer within reach of this file'
Assert-That `
    -Condition ($null -ne $unfakedError -and $unfakedError.Exception.Message -like '*Set-EnvironmentValue (it is not the stand-in)*') `
    -Message 'The guard refuses a module whose seam is still the real one'
Assert-Equal -Expected 0 -Actual $leftLoaded.Count -Message 'and that module is gone before the next case'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a seam that looks like the stand-in but was not defined by the helper
$lookalike = Import-Module $manifest -Force -PassThru -Function @()
Use-FakeEnvironmentStore -Module $lookalike
& $lookalike {
    function script:Set-EnvironmentValue {
        param($Name, $Value, $Target)
        $script:FakeEnvironment["$Target|$Name"] = $Value
    }
}

# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-FakeEnvironmentStore -Module $lookalike
} -MessageLike '*Set-EnvironmentValue (it is not the stand-in)*' `
    -Message 'The seam must be the helper''s own stand-in, not anything that mentions it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a writer that no longer goes through the seam
$bypass = Import-Module $manifest -Force -PassThru -Function @()
Use-FakeEnvironmentStore -Module $bypass
& $bypass {
    function script:Set-EnvironmentVariable {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSReviewUnusedParameter',
            '',
            Justification = 'Read by the script block or child process the test hands it to, by scope.')]
        param($Name, $Value)
        Write-Output "$Name"
    }
}

# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-FakeEnvironmentStore -Module $bypass
} -MessageLike '*Set-EnvironmentVariable (it does not write through Set-EnvironmentValue)*' `
    -Message 'Set-EnvironmentVariable must reach the stand-in for its writes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - other ways a function could write the persisted settings, as text
$writers = @(
    @{
        Name   = 'SetEnvironmentVariable'
        Define = { function script:Get-HostFact { '[Environment]::SetEnvironmentVariable(''P'', ''v'', ''User'')' | Out-Null } }
    }
    @{
        Name   = 'setx'
        Define = { function script:Get-HostFact { 'setx P v' | Out-Null } }
    }
    @{
        Name   = 'a registry drive'
        Define = { function script:Get-HostFact { 'Set-ItemProperty -Path HKCU:\Environment -Name P -Value v' | Out-Null } }
    }
    @{
        Name   = 'the registry class'
        Define = { function script:Get-HostFact { '[Microsoft.Win32.Registry]::CurrentUser' | Out-Null } }
    }
)

foreach ($writer in $writers) {
    $doctored = Import-Module $manifest -Force -PassThru -Function @()
    Use-FakeEnvironmentStore -Module $doctored
    & $doctored $writer.Define

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Assert-FakeEnvironmentStore -Module $doctored
    } -MessageLike '*no test runs: Get-HostFact.' -Message "A function that writes with $($writer.Name) is refused"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a writer in the module's root script, outside every function
$copyRoot = Join-Path ([IO.Path]::GetTempPath()) "UserInputGuard_$([Guid]::NewGuid().ToString('N'))"
$copy = Join-Path $copyRoot 'TaffarelJr.UserInput'
try {
    Copy-Item -LiteralPath (Split-Path $manifest) -Destination $copy -Recurse
    $rootScript = Join-Path $copy 'TaffarelJr.UserInput.psm1'
    Add-Content -LiteralPath $rootScript -Value '# setx P v'
    $rooted = Import-Module (Join-Path $copy 'TaffarelJr.UserInput.psd1') -Force -PassThru -Function @()

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Use-FakeEnvironmentStore -Module $rooted
    } -MessageLike '*no test runs: the root script TaffarelJr.UserInput.psm1.' `
        -Message 'A writer in the root script is refused too'
}
finally {
    Remove-Module TaffarelJr.UserInput -Force -ErrorAction Ignore
    Remove-Item -LiteralPath $copyRoot -Recurse -Force -ErrorAction Ignore
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a child or a hostless runspace imports the real module, unfaked
$childScripts = @(
    'Get-Command Set-EnvironmentVariable'
    'Get-Command Set-EnvironmentValue'
    '[Environment]::GetEnvironmentVariable(''SetEnvironmentVariable'')'
)

foreach ($childScript in $childScripts) {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Invoke-ChildPowerShell -Script $childScript -TimeoutSeconds 5
    } -MessageLike '*a script that mentions Set-EnvironmentVariable, Set-EnvironmentValue or SetEnvironmentVariable is refused.' `
        -Message "Invoke-ChildPowerShell refuses: $childScript"
    Assert-Throws -ScriptBlock {
        Measure-HostlessRetry -Script $childScript -TimeoutSeconds 5
    } -MessageLike '*a script that mentions Set-EnvironmentVariable, Set-EnvironmentValue or SetEnvironmentVariable is refused.' `
        -Message 'and so does Measure-HostlessRetry'
}

exit (Complete-TestRun)
