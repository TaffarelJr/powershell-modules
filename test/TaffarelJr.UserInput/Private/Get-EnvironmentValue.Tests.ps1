#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
$module = Get-Module TaffarelJr.UserInput

# Only this process's own variables are read and written here: the User and
# Machine settings are never touched by a test.
$varName = "TAFFARELJR_USERINPUT_TEST_$([Guid]::NewGuid().ToString('N'))"

try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    [Environment]::SetEnvironmentVariable($varName, '  as stored  ')

    # Act
    $value = & $module { param($n) Get-EnvironmentValue -Name $n -Target Process } $varName

    # Assert
    Assert-Equal -Expected '  as stored  ' -Actual $value `
        -Message 'Reads the variable from the place asked for, exactly as stored'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    [Environment]::SetEnvironmentVariable($varName, $null)

    # Act
    $unset = & $module { param($n) Get-EnvironmentValue -Name $n -Target Process } $varName

    # Assert
    Assert-Equal -Expected $null -Actual $unset -Message 'A variable that is not set there is $null'
}
finally {
    [Environment]::SetEnvironmentVariable($varName, $null)
}

exit (Complete-TestRun)
