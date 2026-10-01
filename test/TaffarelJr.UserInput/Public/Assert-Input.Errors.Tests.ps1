#Requires -Version 7.4
using namespace System.Collections.Generic
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    #───────────────────────────────────────────────────────────────────────────
    # Act - an empty value that is required, whose caller asked for errors to be hidden
    $output = @()
    $caught = $null
    try {
        $output = @(Assert-Input -Value '' -Require -Label 'Repo name' -ErrorAction $preference)
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $output.Count `
        -Message "Under -ErrorAction $preference a value that fails its rule is not passed on"
    Assert-Equal -Expected 'RuntimeException,Assert-Input' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$caught = $null
try {
    $null = Assert-Input -Value 'maybe' -Choice 'yes', 'no' -Label 'The answer'
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Assert-Input' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A value that breaks its rule raises a terminating error whose ID names the failure and the command'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-Equal -Expected 'The answer must be one of: yes, no' -Actual $caught.TargetObject `
    -Message 'and the target the failure had, which is its message'
Assert-Equal -Expected 'The answer must be one of: yes, no' -Actual $caught.Exception.Message `
    -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
Assert-Throws -ScriptBlock { Assert-Input -Value '' -Require -Label 'Repo name' -ErrorAction Stop } `
    -MessageLike 'Repo name is required' `
    -Message 'Under -ErrorAction Stop a value that fails its rule still throws'

#───────────────────────────────────────────────────────────────────────────────
# Act - a good value, the failing one, and a good one after it
$passed = [List[string]]::new()
$caught = $null
try {
    'one', '', 'two' | Assert-Input -Require | ForEach-Object { $passed.Add($_) }
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Assert-Input' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A failing value in the pipeline raises the terminating error'
Assert-Equal -Expected @('one') -Actual $passed.ToArray() `
    -Message 'the value before it is passed on, and the pipeline stops, so the value after it is not'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same pipeline with the failure hidden: the failing value still ends it
$passed.Clear()
$caught = $null
try {
    'one', '', 'two' | Assert-Input -Require -ErrorAction SilentlyContinue | ForEach-Object { $passed.Add($_) }
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected @('one') -Actual $passed.ToArray() `
    -Message 'Under -ErrorAction SilentlyContinue a failing value still ends the pipeline'

#───────────────────────────────────────────────────────────────────────────────
# Act - a mistake in how the call is made, found before the first value is looked at
$caught = $null
try {
    'one' | Assert-Input -Requirement 'letters only'
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RequirementWithoutPattern,Assert-Input' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A mistake in the call keeps its own ID, once, with the command named'
Assert-Equal -Expected ([ErrorCategory]::InvalidArgument) -Actual $caught.CategoryInfo.Category `
    -Message 'and its category'
Assert-Equal -Expected 'letters only' -Actual $caught.TargetObject -Message 'and its target'

exit (Complete-TestRun)
