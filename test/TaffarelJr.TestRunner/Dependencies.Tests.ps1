#Requires -Version 7.4
using namespace System.Collections.Generic

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test defines same-named commands in the global scope, as another module or a script would.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A module calls the commands of the modules it requires through its own scope,
# so a command of the same name that turns up in the global scope later - from
# another module, or a script - does not take its place.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$source = Join-Path $repoRoot 'src'
$modulePaths = foreach ($name in 'Tally', 'ConsoleOutput', 'ProcessInvocation', 'RequiredModules', 'TestRunner') {
    Join-Path $source "TaffarelJr.$name" "TaffarelJr.$name.psd1"
}

Import-Module (Join-Path $source 'TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
foreach ($modulePath in $modulePaths) {
    Import-Module $modulePath -Force
}

. (Join-Path $PSScriptRoot 'TestRunnerTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the commands the module really calls, one from each module it requires,
# defined in the global scope after the imports
$global:ImpostorCalls = [List[string]]::new()
foreach ($name in 'Invoke-NativeRead', 'Read-Tally', 'Write-Detail', 'Assert-RequiredModule') {
    Set-Item -LiteralPath "Function:global:$name" -Value ([scriptblock]::Create("`$global:ImpostorCalls.Add('$name')"))
}

$sandbox = New-TestRunnerSandbox
$testRoot = Join-Path $sandbox 'test'
$sourceRoot = Join-Path $sandbox 'src'
New-Item -ItemType Directory -Path $sourceRoot | Out-Null
New-TestFileStub -Directory $testRoot -Name 'One' | Out-Null
$wrapper = New-FakeWrapper -Directory $sandbox -Body "Write-Host '1 passed, 0 failed'"

# Act - one test file, run through the module's own process runner
$result = Invoke-TestFileProcess `
    -File (Join-Path $testRoot 'One.Tests.ps1') `
    -Name 'One' `
    -SourceRoot $sourceRoot `
    -Coverage `
    -ReportPath (Join-Path $sandbox 'report.xml') `
    -ResultPath (Join-Path $sandbox 'result.xml') `
    -WrapperPath $wrapper

# Assert
Assert-Equal -Expected @() -Actual @($global:ImpostorCalls) `
    -Message 'The process is started and its tally read by the required modules'' commands, not the ones defined later'
Assert-Equal -Expected 1 -Actual $result.Passed -Message 'so the file''s result is the real one'

#───────────────────────────────────────────────────────────────────────────────
# Act - a whole run, which reports with Write-Detail and checks Pester with Assert-RequiredModule
$run = Invoke-TestRun `
    -Path $testRoot `
    -SourceRoot $sourceRoot `
    -Coverage `
    -OutputPath (Join-Path $sandbox 'coverage') `
    -ResultsPath (Join-Path $sandbox 'results') `
    -WrapperPath $wrapper 6>$null

# Assert
Assert-Equal -Expected @() -Actual @($global:ImpostorCalls) `
    -Message 'A run reports and checks its prerequisites with the required modules'' commands as well'
Assert-Equal -Expected 0 -Actual $run.ExitCode -Message 'and its file passes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every module loaded again, the required ones first, as a script that reloads them would
foreach ($modulePath in $modulePaths) {
    Import-Module $modulePath -Force
}

# Act
$again = Invoke-TestFileProcess `
    -File (Join-Path $testRoot 'One.Tests.ps1') `
    -Name 'One' `
    -SourceRoot $sourceRoot `
    -Coverage `
    -ReportPath (Join-Path $sandbox 'report.xml') `
    -ResultPath (Join-Path $sandbox 'result.xml') `
    -WrapperPath $wrapper

# Assert
Assert-Equal -Expected @() -Actual @($global:ImpostorCalls) `
    -Message 'The same holds after the modules are imported again with -Force'
Assert-Equal -Expected 1 -Actual $again.Passed -Message 'and the result is still the real one'

foreach ($name in 'Invoke-NativeRead', 'Read-Tally', 'Write-Detail', 'Assert-RequiredModule') {
    Remove-Item -LiteralPath "Function:\$name"
}

Remove-TestRunnerSandbox -Path $sandbox

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one of the required modules not loaded
Remove-Module -Name 'TaffarelJr.RequiredModules' -Force

# Act / Assert - the module's root script says what is missing, rather than leave a call to fail later
Assert-Throws -ScriptBlock {
    Import-Module (Join-Path $source 'TaffarelJr.TestRunner/TaffarelJr.TestRunner.psm1') -Force
} -MessageLike '*TaffarelJr.RequiredModules must be loaded before TaffarelJr.TestRunner.*' `
    -Message 'A module imported without a module it requires says which one has to be loaded first'

exit (Complete-TestRun)
