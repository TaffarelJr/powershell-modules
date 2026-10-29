#Requires -Version 7.4
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')

# The stand-in Read-Host fails when it is asked with no answer queued, as the
# real one does where no one can answer.
Install-FakeReadHost
$message = 'Read-Host was asked more often than the test gave answers.'

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    #───────────────────────────────────────────────────────────────────────────
    # Act - a gate that cannot ask, whose caller asked for errors to be hidden
    $output = @()
    $caught = $null
    try {
        $output = @(Confirm-Proceed -Action 'delete the branch' -ErrorAction $preference)
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $output.Count `
        -Message "Under -ErrorAction $preference a gate that cannot ask gives no answer"
    Assert-Equal -Expected 'RuntimeException,Confirm-Proceed' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$caught = $null
try {
    $null = Confirm-Proceed -Action 'delete the branch'
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Confirm-Proceed' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A gate that cannot ask raises a terminating error whose ID names the failure and the command'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-Equal -Expected $message -Actual $caught.TargetObject `
    -Message 'and the target the failure had, which is its message'
Assert-Equal -Expected $message -Actual $caught.Exception.Message -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
Assert-Throws -ScriptBlock { Confirm-Proceed -Action 'delete the branch' -ErrorAction Stop } `
    -MessageLike 'Read-Host was asked*' `
    -Message 'Under -ErrorAction Stop a gate that cannot ask still throws'

exit (Complete-TestRun)
