#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'TestRunnerTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' '..' 'PreferenceTestHelper.ps1')
Install-VerboseCaller

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one test file, and a wrapper that only passes
$sandbox = New-TestRunnerSandbox
$testRoot = Join-Path $sandbox 'test'
$sourceRoot = Join-Path $sandbox 'src'
New-Item -ItemType Directory -Path $sourceRoot | Out-Null
New-TestFileStub -Directory $testRoot -Name 'One' | Out-Null
$wrapper = New-FakeWrapper -Directory $sandbox -Body "Write-Host '1 passed, 0 failed'"
$call = @{
    Path        = $testRoot
    SourceRoot  = $sourceRoot
    Coverage    = $true
    OutputPath  = Join-Path $sandbox 'coverage'
    ResultsPath = Join-Path $sandbox 'results'
    WrapperPath = $wrapper
}

# Act
$all = @(Get-VerboseLine { $null = Invoke-TestRun @call -Verbose 6>$null })
$lines = @($all | Where-Object { $_ -like "Running 'One'*" })

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count `
    -Message '-Verbose shows the command line of each test file''s process, even though it runs in a worker'
Assert-That -Condition ($lines[0].Contains("-TestFile $(Join-Path $testRoot 'One.Tests.ps1')")) `
    -Message 'naming the file'

#───────────────────────────────────────────────────────────────────────────────
# Act
$quiet = @(Get-VerboseLine { $null = Invoke-TestRun @call 6>$null })

# Assert
Assert-Equal -Expected 0 -Actual @($quiet | Where-Object { $_ -like "Running 'One'*" }).Count `
    -Message 'Without -Verbose nothing is said'

#───────────────────────────────────────────────────────────────────────────────
# Act - the switch given to a command of another module, which calls this one without it
$all = @(Get-VerboseLine { $null = Invoke-RunCaller -Call $call -Verbose })

# Assert
Assert-Equal -Expected 1 -Actual @($all | Where-Object { $_ -like "Running 'One'*" }).Count `
    -Message 'A call made from another module under -Verbose is shown too'

#───────────────────────────────────────────────────────────────────────────────
# Act
$quiet = @(Get-VerboseLine { $null = Invoke-RunCaller -Call $call })

# Assert
Assert-Equal -Expected 0 -Actual @($quiet | Where-Object { $_ -like "Running 'One'*" }).Count `
    -Message 'A call from another module that asked for nothing says nothing'

Remove-TestRunnerSandbox -Path $sandbox

exit (Complete-TestRun)
