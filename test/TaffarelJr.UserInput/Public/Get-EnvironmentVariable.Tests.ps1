#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')
$module = Get-Module TaffarelJr.UserInput

# The User and Machine settings are a stand-in, so nothing here changes the
# real ones; this process's own variable is real, and its name is unique.
Use-FakeEnvironmentStore -Module $module
$varName = "TAFFARELJR_USERINPUT_TEST_$([Guid]::NewGuid().ToString('N'))"

# $IsWindows is forced, so the User and Machine lookup, which only Windows
# has, is tested on every platform. It is read-only, hence -Force, and it is
# put back however the cases end.
$originalIsWindows = $IsWindows
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Variable -Name IsWindows -Value $true -Force -Scope Global

    # Act
    $unset = Get-EnvironmentVariable -Name $varName

    # Assert
    Assert-Equal -Expected $null -Actual $unset -Message 'A variable that is set nowhere is $null'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    [Environment]::SetEnvironmentVariable($varName, '  value  ')

    # Act
    $padded = Get-EnvironmentVariable -Name $varName

    # Assert
    Assert-Equal -Expected '  value  ' -Actual $padded -Message 'A set value is returned exactly as stored, not trimmed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    [Environment]::SetEnvironmentVariable($varName, '   ')

    # Act
    $blank = Get-EnvironmentVariable -Name $varName

    # Assert
    Assert-Equal -Expected $null -Actual $blank -Message 'A whitespace-only value is treated the same as unset'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - saved in the User settings, but not in this process
    [Environment]::SetEnvironmentVariable($varName, $null)
    Set-FakeStoredValue -Module $module -Name $varName -Value '  persisted  ' -Target User

    # Act
    $found = Get-EnvironmentVariable -Name $varName

    # Assert
    Assert-Equal -Expected '  persisted  ' -Actual $found `
        -Message 'A value in the User settings is found, though this process was started before it was saved'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - this process has its own value too
    [Environment]::SetEnvironmentVariable($varName, 'this-run')

    # Act
    $own = Get-EnvironmentVariable -Name $varName

    # Assert
    Assert-Equal -Expected 'this-run' -Actual $own -Message 'This process''s own value wins over the saved one'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - this process's value is only spaces
    [Environment]::SetEnvironmentVariable($varName, '   ')

    # Act
    $behindBlank = Get-EnvironmentVariable -Name $varName

    # Assert
    Assert-Equal -Expected '  persisted  ' -Actual $behindBlank `
        -Message 'A blank value counts as unset, so the saved one is found'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - only the Machine settings have it; the User value is blank
    [Environment]::SetEnvironmentVariable($varName, $null)
    Set-FakeStoredValue -Module $module -Name $varName -Value ' ' -Target User
    Set-FakeStoredValue -Module $module -Name $varName -Value 'machine-value' -Target Machine

    # Act
    $machine = Get-EnvironmentVariable -Name $varName

    # Assert
    Assert-Equal -Expected 'machine-value' -Actual $machine `
        -Message 'The Machine settings are looked in last, past a blank User value'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a platform with no User or Machine settings
    Set-Variable -Name IsWindows -Value $false -Force -Scope Global

    # Act
    $elsewhere = Get-EnvironmentVariable -Name $varName

    # Assert
    Assert-Equal -Expected $null -Actual $elsewhere -Message 'Off Windows only this process is looked in'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the documented flow: a secret saved on one run, read on the next
    Set-Variable -Name IsWindows -Value $true -Force -Scope Global
    $secretName = "$($varName)_SECRET"
    Install-FakeReadHost
    Use-FakeHost -Module $module
    Add-FakeAnswer '  s3cr3t  '
    Read-Secret -Prompt 'Token' | Set-EnvironmentVariable -Name $secretName
    [Environment]::SetEnvironmentVariable($secretName, $null)

    # Act
    $nextRun = Get-EnvironmentVariable -Name $secretName

    # Assert
    Assert-Equal -Expected '  s3cr3t  ' -Actual $nextRun `
        -Message 'A secret saved by Read-Secret | Set-EnvironmentVariable comes back unchanged on the next run'
}
finally {
    Set-Variable -Name IsWindows -Value $originalIsWindows -Force -Scope Global
    [Environment]::SetEnvironmentVariable($varName, $null)
    [Environment]::SetEnvironmentVariable("$($varName)_SECRET", $null)
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
        $null = Get-EnvironmentVariable -Name $bad.Value
    } -MessageLike "*Environment variable name '$($bad.Value)' must not be blank, start with a space, or contain '='" `
        -Message "A name with $($bad.Name) is refused"
}

exit (Complete-TestRun)
