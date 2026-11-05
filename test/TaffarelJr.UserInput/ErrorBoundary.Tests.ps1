#Requires -Version 7.4
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# What a caller sees when a prompt or a check fails inside a public function:
# one terminating error, with an ID that names the failure and every command it
# passed through, and the failure's own message and target.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot 'UserInputTestHelper.ps1')
$module = Get-Module TaffarelJr.UserInput

# The prompts: Read-Host fails with no answer queued, and no one can be asked again.
Install-FakeReadHost
Use-FakeHost -Module $module -UserInteractive $false
Use-FakeEnvironmentStore -Module $module
$unanswered = 'Read-Host was asked more often than the test gave answers.'
$prompted = @(
    @{ Name = 'Read-Input'; Run = { Read-Input -Prompt 'x' }; Id = 'RuntimeException,Read-Input' }
    @{ Name = 'Read-Secret'; Run = { Read-Secret -Prompt 'x' }; Id = 'RuntimeException,Read-Secret' }
    @{
        Name = 'Confirm-Input'
        Run  = { Confirm-Input -Prompt 'x' }
        Id   = 'RuntimeException,Read-Input,Invoke-InputRetry,Confirm-Input'
    }
    @{
        Name = 'Select-Choice'
        Run  = { Select-Choice -Prompt 'x' -Option 'a', 'b' }
        Id   = 'RuntimeException,Invoke-InputRetry,Select-Choice'
    }
)

foreach ($case in $prompted) {
    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        # Act - a prompt that cannot be answered, whose caller asked for errors to be hidden
        $output = @()
        $caught = $null
        try {
            $output = @(& $case.Run -ErrorAction $preference 6>$null)
        }
        catch {
            $caught = $_
        }

        # Assert
        Assert-Equal -Expected 0 -Actual $output.Count `
            -Message "Under -ErrorAction $preference $($case.Name) gives no answer when it cannot ask"
        Assert-Equal -Expected $case.Id -Actual $caught.FullyQualifiedErrorId `
            -Message 'and the failure is still raised, as a terminating error'
    }
}

foreach ($case in $prompted) {
    # Act
    $caught = $null
    try {
        $null = & $case.Run 6>$null
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
        -Message "The failure of $($case.Name) has a category a caller can act on"
    Assert-Equal -Expected $unanswered -Actual $caught.Exception.Message `
        -Message 'and the message of the failure'
    Assert-Equal -Expected $unanswered -Actual $caught.TargetObject `
        -Message 'and the target the failure had, which is its message'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a host that cannot be inspected
& $module { function script:Get-HostFact { throw 'The host could not be inspected.' } }
$uninspectable = @(
    @{ Name = 'Test-InteractiveHost'; Run = { Test-InteractiveHost }; Id = 'RuntimeException,Test-InteractiveHost' }
    @{
        Name = 'Wait-KeyPress'
        Run  = { Wait-KeyPress }
        Id   = 'RuntimeException,Test-InteractiveHost,Wait-KeyPress'
    }
)

foreach ($case in $uninspectable) {
    # Act
    $output = @()
    $caught = $null
    try {
        $output = @(& $case.Run -ErrorAction SilentlyContinue)
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $output.Count `
        -Message "Under -ErrorAction SilentlyContinue $($case.Name) gives no answer when the host cannot be inspected"
    Assert-Equal -Expected $case.Id -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is raised, as a terminating error'
    Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
        -Message 'with a category a caller can act on'
    Assert-Equal -Expected 'The host could not be inspected.' -Actual $caught.TargetObject `
        -Message 'and the target the failure had, which is its message'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - settings that cannot be read
$broken = "TAFFARELJR_USERINPUT_BOUNDARY_$([Guid]::NewGuid().ToString('N'))"
Set-FakeStoreFailure -Module $module -Name $broken

# Act
$output = @()
$caught = $null
try {
    $output = @(Get-EnvironmentVariable -Name $broken -ErrorAction SilentlyContinue)
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 0 -Actual $output.Count `
    -Message 'A variable that cannot be read gives no value, even with errors hidden'
Assert-Equal -Expected 'RuntimeException,Get-EnvironmentVariable' -Actual $caught.FullyQualifiedErrorId `
    -Message 'and the failure is raised, as a terminating error whose ID names the failure and the command'
Assert-Equal -Expected "The settings for $broken could not be read." -Actual $caught.Exception.Message `
    -Message 'with the message of the failure'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'and a category a caller can act on'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a call mistake that cannot even be described
& $module { function script:New-CallMistakeError { throw 'The error could not be built.' } }

# Act
$caught = $null
try {
    $null = Assert-Input -Value 'a' -Requirement 'letters only' -ErrorAction SilentlyContinue
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Assert-Input' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A failure while the call is being checked is raised as a terminating error too'
Assert-Equal -Expected 'The error could not be built.' -Actual $caught.Exception.Message `
    -Message 'with the message of the failure'

exit (Complete-TestRun)
