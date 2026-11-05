#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
$module = Get-Module TaffarelJr.UserInput

# Only this process's own variables are written here: the User and Machine
# settings are never touched by a test.
$varName = "TAFFARELJR_USERINPUT_TEST_$([Guid]::NewGuid().ToString('N'))"

try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    & $module { param($n) Set-EnvironmentValue -Name $n -Value '  written  ' -Target Process } $varName

    # Assert
    Assert-Equal -Expected '  written  ' -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'Writes the variable to the place asked for, exactly as given'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    & $module { param($n) Set-EnvironmentValue -Name $n -Value '' -Target Process } $varName

    # Assert
    Assert-Equal -Expected $null -Actual ([Environment]::GetEnvironmentVariable($varName)) `
        -Message 'An empty value removes it'
}
finally {
    [Environment]::SetEnvironmentVariable($varName, $null)
}

exit (Complete-TestRun)
