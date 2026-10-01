#Requires -Version 7.4
using namespace System.Management.Automation

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
$first = "TAFFARELJR_USERINPUT_ERRORS_$([Guid]::NewGuid().ToString('N'))"
$broken = "TAFFARELJR_USERINPUT_ERRORS_$([Guid]::NewGuid().ToString('N'))"
$last = "TAFFARELJR_USERINPUT_ERRORS_$([Guid]::NewGuid().ToString('N'))"
$message = "The settings for $broken could not be written."
Set-FakeStoreFailure -Module $module -Name $broken

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    #───────────────────────────────────────────────────────────────────────────
    # Act - a write that fails, whose caller asked for errors to be hidden
    $caught = $null
    try {
        Set-EnvironmentVariable -Name $broken -Value 'x' -ErrorAction $preference
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected $null -Actual ([Environment]::GetEnvironmentVariable($broken)) `
        -Message "Under -ErrorAction $preference a write that fails does not go on to the next scope"
    Assert-Equal -Expected 'RuntimeException,Set-EnvironmentVariable' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$caught = $null
try {
    Set-EnvironmentVariable -Name $broken -Value 'x'
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Set-EnvironmentVariable' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A write that fails raises a terminating error whose ID names the failure and the command'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-Equal -Expected $message -Actual $caught.TargetObject `
    -Message 'and the target the failure had, which is its message'
Assert-Equal -Expected $message -Actual $caught.Exception.Message -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
Assert-Throws -ScriptBlock { Set-EnvironmentVariable -Name $broken -Value 'x' -ErrorAction Stop } `
    -MessageLike "*$broken*could not be written*" `
    -Message 'Under -ErrorAction Stop a write that fails still throws'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - three variables to write, the middle one broken
$records = foreach ($name in $first, $broken, $last) {
    [PSCustomObject]@{ Name = $name; Value = 'value' }
}

# Act
$caught = $null
try {
    $records | Set-EnvironmentVariable
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Set-EnvironmentVariable' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A failing record in the pipeline raises the terminating error'
Assert-Equal -Expected 'value' -Actual ([Environment]::GetEnvironmentVariable($first)) `
    -Message 'the record before it is written'
Assert-Equal -Expected $null -Actual ([Environment]::GetEnvironmentVariable($last)) `
    -Message 'and the pipeline stops, so the record after it is not'

[Environment]::SetEnvironmentVariable($first, $null)

exit (Complete-TestRun)
