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
# Arrange - a wrapper that only passes, and one file to run through it
$sandbox = New-TestRunnerSandbox
$wrapper = New-FakeWrapper -Directory $sandbox -Body "Write-Host '1 passed, 0 failed'"
$testFile = Join-Path $sandbox 'Some.Tests.ps1'
$call = @{
    File        = $testFile
    Name        = 'Some'
    SourceRoot  = Join-Path $sandbox 'src'
    Coverage    = $true
    ReportPath  = Join-Path $sandbox 'report.xml'
    ResultPath  = Join-Path $sandbox 'result.xml'
    WrapperPath = $wrapper
}

# Act
$all = @(Get-VerboseLine { $null = Invoke-TestFileProcess @call -Verbose })
$lines = @($all | Where-Object { $_ -like "Running 'Some'*" })

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message '-Verbose says once what it is about to run'
Assert-That -Condition ($lines[0] -like "Running 'Some' in a new process: *pwsh* -NoProfile -NonInteractive -File *") `
    -Message 'as the command line of the process'
Assert-That -Condition ($lines[0].Contains("-TestFile $testFile")) -Message 'with the file it is given'
Assert-That -Condition ($lines[0].Contains("-ResultPath $($call.ResultPath)")) -Message 'and where its results go'
Assert-Equal -Expected 1 -Actual @($all | Where-Object { $_ -like '*-NoProfile*' }).Count `
    -Message 'and the command line is not repeated by the module that runs it'

#───────────────────────────────────────────────────────────────────────────────
# Act
$quiet = @(Get-VerboseLine { $null = Invoke-TestFileProcess @call })

# Assert
Assert-Equal -Expected 0 -Actual @($quiet | Where-Object { $_ -like "Running 'Some'*" }).Count `
    -Message 'Without -Verbose nothing is said'

#───────────────────────────────────────────────────────────────────────────────
# Act - the switch given to a command of another module, which calls this one without it
$all = @(Get-VerboseLine { $null = Invoke-FileProcessCaller -Call $call -Verbose })

# Assert
Assert-Equal -Expected 1 -Actual @($all | Where-Object { $_ -like "Running 'Some'*" }).Count `
    -Message 'A call made from another module under -Verbose is shown too'
Assert-Equal -Expected 1 -Actual @($all | Where-Object { $_ -like '*-NoProfile*' }).Count `
    -Message 'and its command line is said once there too'

#───────────────────────────────────────────────────────────────────────────────
# Act
$quiet = @(Get-VerboseLine { $null = Invoke-FileProcessCaller -Call $call })

# Assert
Assert-Equal -Expected 0 -Actual @($quiet | Where-Object { $_ -like "Running 'Some'*" }).Count `
    -Message 'A call from another module that asked for nothing says nothing'

#───────────────────────────────────────────────────────────────────────────────
# Act - the session asks for verbose output, and the call itself turns it off
$previous = (Get-Variable -Name VerbosePreference -Scope Global).Value
Set-Variable -Name VerbosePreference -Scope Global -Value 'Continue'
try {
    $off = @(Get-VerboseLine { $null = Invoke-TestFileProcess @call -Verbose:$false })
}
finally {
    Set-Variable -Name VerbosePreference -Scope Global -Value $previous
}

# Assert
Assert-Equal -Expected 0 -Actual @($off | Where-Object { $_ -like "Running 'Some'*" }).Count `
    -Message '-Verbose:$false on the call itself wins over the session'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file run on its own, with no wrapper in between
$directFile = Join-Path $sandbox 'Direct.Tests.ps1'
Set-Content -LiteralPath $directFile -Value @'
Write-Host '1 passed, 0 failed'
exit 0
'@

# Act
$direct = @(Get-VerboseLine {
        $null = Invoke-TestFileProcess -File $directFile -Name 'Direct' -SourceRoot $call.SourceRoot -Verbose
    })
$directLines = @($direct | Where-Object { $_ -like "Running 'Direct'*" })

# Assert
Assert-Equal -Expected 1 -Actual $directLines.Count `
    -Message '-Verbose says once what it is about to run, without -Coverage too'
Assert-That -Condition ($directLines[0].EndsWith("-NonInteractive -File $directFile")) `
    -Message 'as the file itself run by pwsh'
Assert-That -Condition (-not $directLines[0].Contains('-TestFile')) -Message 'with no wrapper script in front of it'

Remove-TestRunnerSandbox -Path $sandbox

exit (Complete-TestRun)
