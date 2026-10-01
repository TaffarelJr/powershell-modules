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

#───────────────────────────────────────────────────────────────────────────────
# Arrange - someone is there to be asked again, so only the kind of failure decides
Use-FakeHost -Module $module
$script:attempts = 0

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    $script:attempts = 0

    # Act - a block that fails on every attempt, whose caller asked for errors to be hidden
    $output = @()
    $caught = $null
    try {
        $output = @(Invoke-InputRetry -MaxAttempt 2 -ErrorAction $preference -ScriptBlock {
                $script:attempts++
                throw 'The answer is no good'
            } 3>$null)
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 2 -Actual $script:attempts `
        -Message "Under -ErrorAction $preference the block is still tried the number of times asked for"
    Assert-Equal -Expected 0 -Actual $output.Count -Message 'and nothing is returned for the failure'
    Assert-Equal -Expected 'RuntimeException,Invoke-InputRetry' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the last failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$script:attempts = 0
$caught = $null
try {
    $null = Invoke-InputRetry -MaxAttempt 2 -ScriptBlock {
        $script:attempts++
        throw 'The answer is no good'
    } 3>$null
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Invoke-InputRetry' -Actual $caught.FullyQualifiedErrorId `
    -Message 'The failure of the last attempt raises a terminating error whose ID names the failure and the command'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-Equal -Expected 'The answer is no good' -Actual $caught.TargetObject `
    -Message 'and the target the failure had, which is its message'
Assert-Equal -Expected 'The answer is no good' -Actual $caught.Exception.Message `
    -Message 'and the message of the failure, which is the block''s own'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
Assert-Throws -ScriptBlock {
    Invoke-InputRetry -MaxAttempt 1 -ErrorAction Stop -ScriptBlock { throw 'The answer is no good' }
} -MessageLike 'The answer is no good' -Message 'Under -ErrorAction Stop the failure still throws'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a mistake in the call, made inside a block that is itself retried
$script:outer = 0

# Act
$caught = $null
try {
    $null = Invoke-InputRetry -ScriptBlock {
        $script:outer++
        Invoke-InputRetry -ScriptBlock { Assert-Input -Value 'a' -Requirement 'letters only' }
    }
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 1 -Actual $script:outer `
    -Message 'A call mistake that comes out of an inner retry is not retried by the outer one either'
Assert-Equal -Expected 'RequirementWithoutPattern,Assert-Input,Invoke-InputRetry,Invoke-InputRetry' `
    -Actual $caught.FullyQualifiedErrorId `
    -Message 'and keeps its own ID, followed by each command it passed through'

exit (Complete-TestRun)
