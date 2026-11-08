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

$module = Get-Module -Name 'TaffarelJr.TestRunner'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a passing TestKit file with two assertions, run with no report paths
$directRoot = New-TestRunnerSandbox
$directSource = Join-Path $directRoot 'src'
$passFile = Join-Path $directRoot 'Pass.Tests.ps1'
Set-Content -LiteralPath $passFile -Value (Get-TestKitFileContent -Body @'
Assert-That -Condition $true -Message 'first'
Assert-That -Condition $true -Message 'second'
'@)

# Act
$passed = Invoke-TestFileProcess -File $passFile -Name 'Pass' -SourceRoot $directSource
$reports = @(Get-ChildItem -LiteralPath $directRoot -Recurse -File -Filter '*.xml')

# Assert
Assert-Equal -Expected 2 -Actual $passed.Passed -Message 'A file run on its own reports the passed count of its tally'
Assert-Equal -Expected 0 -Actual $passed.Failed -Message 'and the failed count'
Assert-Equal -Expected $false -Actual $passed.Crashed `
    -Message 'A file that printed its tally and exited cleanly did not crash'
Assert-Equal -Expected 0 -Actual $passed.ExitCode -Message 'and its exit code is its own'
Assert-Equal -Expected 0 -Actual $reports.Count -Message 'Without -Coverage no coverage or result report is written'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a TestKit file with a failing assertion
$failFile = Join-Path $directRoot 'Fail.Tests.ps1'
Set-Content -LiteralPath $failFile -Value (Get-TestKitFileContent -Body @'
Assert-That -Condition $false -Message 'it fails'
'@)

# Act
$failed = Invoke-TestFileProcess -File $failFile -Name 'Fail' -SourceRoot $directSource

# Assert
Assert-Equal -Expected 1 -Actual $failed.Failed -Message 'A file run on its own reports its failed cases'
Assert-Equal -Expected 1 -Actual $failed.ExitCode -Message 'and exits with the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file with no exit statement, which would leave a mark if it ran
$noExitMarker = Join-Path $directRoot 'no-exit-ran.txt'
$noExitFile = Join-Path $directRoot 'NoExit.Tests.ps1'
Set-Content -LiteralPath $noExitFile -Value (Get-TestKitFileContent -NoExit -Body @"
Set-Content -LiteralPath '$noExitMarker' -Value 'ran'
"@)

# Act
$noExit = Invoke-TestFileProcess -File $noExitFile -Name 'NoExit' -SourceRoot $directSource

# Assert
Assert-Equal -Expected $true -Actual $noExit.Crashed -Message 'A file with no exit statement counts as crashed'
Assert-Equal -Expected @('The file has no exit statement; it must end with exit (Complete-TestRun).') `
    -Actual $noExit.Output -Message 'and its output says why'
Assert-Equal -Expected 1 -Actual $noExit.ExitCode -Message 'with the exit code of a file that never reached its end'
Assert-That -Condition (-not (Test-Path -LiteralPath $noExitMarker)) -Message 'and it was never run'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file with a syntax error after a line that would leave a mark
$syntaxMarker = Join-Path $directRoot 'syntax-ran.txt'
$syntaxFile = Join-Path $directRoot 'Syntax.Tests.ps1'
Set-Content -LiteralPath $syntaxFile -Value @"
Set-Content -LiteralPath '$syntaxMarker' -Value 'ran'
if (
"@
$syntaxLine = [WildcardPattern]::Escape($syntaxFile) + ':2:5: *'

# Act
$syntax = Invoke-TestFileProcess -File $syntaxFile -Name 'Syntax' -SourceRoot $directSource

# Assert
Assert-Equal -Expected $true -Actual $syntax.Crashed -Message 'A file that does not parse counts as crashed'
Assert-Equal -Expected 1 -Actual @($syntax.Output).Count -Message 'with one line of output for its one error'
Assert-That -Condition (@($syntax.Output)[0] -like $syntaxLine) `
    -Message 'which names the file, the line and the column, then the parser''s message'
Assert-That -Condition (-not (Test-Path -LiteralPath $syntaxMarker)) -Message 'and it was never run'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that is not there
$absentFile = Join-Path $directRoot 'Absent.Tests.ps1'

# Act
$absent = Invoke-TestFileProcess -File $absentFile -Name 'Absent' -SourceRoot $directSource

# Assert
Assert-Equal -Expected $true -Actual $absent.Crashed -Message 'A file that is not there counts as crashed'
Assert-That -Condition (($absent.Output -join "`n") -like '*could not be read*') `
    -Message 'and its output says it could not be read'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that fails with an error of its own, before it reaches any exit
$blownFile = Join-Path $directRoot 'Blown.Tests.ps1'
Set-Content -LiteralPath $blownFile -Value @'
throw 'the file blew up'
exit 0
'@

# Act
$blown = Invoke-TestFileProcess -File $blownFile -Name 'Blown' -SourceRoot $directSource

# Assert
Assert-Equal -Expected $true -Actual $blown.Crashed `
    -Message 'A file that throws before it prints a tally counts as crashed'
Assert-That -Condition (($blown.Output -join "`n") -like '*the file blew up*') `
    -Message 'and the error it ended with is in its output'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that says what Pester it was handed, run with a Pester path
# in the parent's environment and one given, none of which a direct run uses
$handedFile = Join-Path $directRoot 'Handed.Tests.ps1'
Set-Content -LiteralPath $handedFile -Value @'
Write-Host "pester=[$env:TESTRUNNER_PESTER_PATH]"
Write-Host '1 passed, 0 failed'
exit 0
'@
$inherited = $env:TESTRUNNER_PESTER_PATH
$env:TESTRUNNER_PESTER_PATH = 'inherited'

# Act
try {
    $handed = Invoke-WithSeam -Module $module -Name 'Get-LoadedPesterPath' `
        -Replacement { throw 'Get-LoadedPesterPath was called without -Coverage' } `
        -ScriptBlock {
            Invoke-TestFileProcess -File $handedFile -Name 'Handed' -SourceRoot $directSource `
                -PesterPath 'given-path' -WrapperPath (Join-Path $directRoot 'no-wrapper.ps1')
        }
}
finally {
    $env:TESTRUNNER_PESTER_PATH = $inherited
}

# Assert
Assert-That -Condition ($handed.Output -contains 'pester=[]') `
    -Message 'A file run on its own is handed no Pester path, whatever this process or -PesterPath holds'
Assert-Equal -Expected 1 -Actual $handed.Passed `
    -Message 'and neither the loaded Pester nor the wrapper is looked for'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two source folders that exist, side by side, and a file that says where it started
$directShared = Join-Path $directRoot 'shared'
$directA = New-Item -ItemType Directory -Path (Join-Path $directShared 'A')
$directB = New-Item -ItemType Directory -Path (Join-Path $directShared 'B')
$whereFile = Join-Path $directRoot 'Where.Tests.ps1'
Set-Content -LiteralPath $whereFile -Value @'
Write-Host "location=$((Get-Location).Path)"
Write-Host '1 passed, 0 failed'
exit 0
'@

# Act
$where = Invoke-TestFileProcess -File $whereFile -Name 'Where' -SourceRoot @($directA.FullName, $directB.FullName)

# Assert
Assert-That -Condition ($where.Output -contains "location=$directShared") `
    -Message 'A file run on its own starts in the deepest folder holding every -SourceRoot'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - the coverage wrapper needs somewhere to write its two reports
Assert-Throws -ScriptBlock {
    Invoke-TestFileProcess -File $absentFile -Name 'Some' -SourceRoot $directSource -Coverage `
        -ResultPath (Join-Path $directRoot 'result.xml')
} -MessageLike '*-Coverage needs -ReportPath and -ResultPath*' `
    -Message '-Coverage without -ReportPath is refused before anything is read or started'
Assert-Throws -ScriptBlock {
    Invoke-TestFileProcess -File $absentFile -Name 'Some' -SourceRoot $directSource -Coverage `
        -ReportPath (Join-Path $directRoot 'report.xml')
} -MessageLike '*-Coverage needs -ReportPath and -ResultPath*' `
    -Message 'and so is -Coverage without -ResultPath'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake wrapper standing in for Invoke-TestFile.ps1,
# so this test exercises Invoke-TestFileProcess's own
# process-spawning and output-parsing logic
# without needing real Pester coverage machinery
$sandbox = New-TestRunnerSandbox
$sourceRoot = Join-Path $sandbox 'src'
$testFile = Join-Path $sandbox 'Some.Tests.ps1'
$reportPath = Join-Path $sandbox 'report.xml'
$resultPath = Join-Path $sandbox 'result.xml'
$sawWrapper = New-FakeWrapper -Directory $sandbox -Body @'
Write-Host "saw TestFile=$TestFile SourceRoot=$SourceRoot OutputPath=$OutputPath ResultPath=$ResultPath"
Write-Host '2 passed, 1 failed'
exit 1
'@

# Act
$result = Invoke-TestFileProcess `
    -File $testFile `
    -Name 'Some' `
    -SourceRoot $sourceRoot `
    -Coverage `
    -ReportPath $reportPath `
    -ResultPath $resultPath `
    -WrapperPath $sawWrapper
$seen = $result.Output -join "`n"

# Assert
Assert-Equal -Expected 'Some' -Actual $result.Name -Message 'The result carries the given display name'
Assert-Equal -Expected 2 -Actual $result.Passed -Message "Reads the passed count from the wrapper's output"
Assert-Equal -Expected 1 -Actual $result.Failed -Message "Reads the failed count from the wrapper's output"
Assert-Equal -Expected 1 -Actual $result.ExitCode -Message "Captures the wrapper's own exit code"
Assert-Equal -Expected $false -Actual $result.Crashed `
    -Message 'A real tally with a matching failed count is not a crash'
Assert-Equal -Expected $false -Actual $result.TimedOut -Message 'A file that finished did not time out'
Assert-That -Condition $seen.Contains("TestFile=$testFile") -Message 'The wrapper is invoked with the given TestFile'
Assert-That -Condition $seen.Contains("SourceRoot=$sourceRoot") `
    -Message 'The wrapper is invoked with the given SourceRoot'
Assert-That -Condition $seen.Contains("OutputPath=$reportPath") `
    -Message 'The wrapper is invoked with the given ReportPath as its OutputPath'
Assert-That -Condition $seen.Contains("ResultPath=$resultPath") `
    -Message 'The wrapper is invoked with the given ResultPath'
Assert-That -Condition ($result.Seconds -ge 0) -Message 'Timing is captured as a non-negative number'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - several -SourceRoot folders, which can only cross into the
# spawned process as one delimited string (see Expand-PathList's own doc
# comment for why a bare multi-element array does not survive that hop)
$first = Join-Path $sandbox 'src' 'A'
$second = Join-Path $sandbox 'src' 'B'
$multiResult = Invoke-TestFileProcess `
    -File $testFile `
    -Name 'Some' `
    -SourceRoot @($first, $second) `
    -Coverage `
    -ReportPath $reportPath `
    -ResultPath $resultPath `
    -WrapperPath $sawWrapper

# Assert
Assert-That -Condition (($multiResult.Output -join "`n").Contains("SourceRoot=$first$([Path]::PathSeparator)$second")) `
    -Message 'Several -SourceRoot folders arrive at the wrapper joined by the platform path separator'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a folder that cannot be told apart from two
$separator = [Path]::PathSeparator

# Assert
Assert-Throws -ScriptBlock {
    Invoke-TestFileProcess -File $testFile -Name 'Some' -SourceRoot "left${separator}right" `
        -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $sawWrapper
} -MessageLike "*-SourceRoot entry 'left${separator}right' contains '$separator'*" `
    -Message 'A -SourceRoot folder containing the list separator is refused, naming it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that prints a failing tally but exits 0
$liarWrapper = New-FakeWrapper -Directory $sandbox -Body "Write-Host '3 passed, 2 failed'`nexit 0"

# Act
$liar = Invoke-TestFileProcess -File $testFile -Name 'Liar' -SourceRoot $sourceRoot `
    -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $liarWrapper

# Assert
Assert-Equal -Expected 2 -Actual $liar.Failed -Message 'The failed count is reported even though the exit code is 0'
Assert-Equal -Expected 0 -Actual $liar.ExitCode -Message 'and the exit code is reported as it was'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that dies without printing a tally
$crashWrapper = New-FakeWrapper -Directory $sandbox -Body "Write-Host 'boom'`nexit 3"

# Act
$crashed = Invoke-TestFileProcess -File $testFile -Name 'Crash' -SourceRoot $sourceRoot `
    -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $crashWrapper

# Assert
Assert-Equal -Expected $true -Actual $crashed.Crashed -Message 'No tally and a failing exit is a crash'
Assert-Equal -Expected 3 -Actual $crashed.ExitCode -Message 'with the exit code it had'
Assert-Equal -Expected $false -Actual $crashed.TimedOut -Message 'which is not a timeout'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - how long this machine takes to get a fake wrapper running, read
# from the readiness marker its first line writes. Every limit below is set
# well past that, so a file prints before it is stopped however busy the
# machine is, and every sleep is far past the limit, so "stopped, not waited
# out" holds too. Then a file that never finishes.
$readyMarker = Join-Path $sandbox 'ready.txt'
$readyWrapper = New-FakeWrapper -Directory $sandbox `
    -Body "Set-Content -LiteralPath '$readyMarker' -Value 'ready'`nWrite-Host '1 passed, 0 failed'`nexit 0"
$launched = [DateTime]::UtcNow
$null = Invoke-TestFileProcess -File $testFile -Name 'Ready' -SourceRoot $sourceRoot `
    -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $readyWrapper
$readySeconds = ((Get-Item -LiteralPath $readyMarker).LastWriteTimeUtc - $launched).TotalSeconds
$limit = [int][Math]::Max(20, [Math]::Ceiling($readySeconds * 3))
$sleep = $limit + 120
$hangWrapper = New-FakeWrapper -Directory $sandbox `
    -Body "Write-Host 'starting'`nStart-Sleep -Seconds $sleep`nWrite-Host '1 passed, 0 failed'"

# Act
$hung = Invoke-TestFileProcess -File $testFile -Name 'Hang' -SourceRoot $sourceRoot `
    -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $hangWrapper -TimeoutSeconds $limit

# Assert
Assert-Equal -Expected $true -Actual $hung.TimedOut -Message 'A file still running at the limit is marked as timed out'
Assert-Equal -Expected $true -Actual $hung.Crashed -Message 'and counts as crashed'
Assert-Equal -Expected 124 -Actual $hung.ExitCode -Message 'with the exit code of a stopped command'
Assert-That -Condition ($hung.Seconds -lt ($sleep - 20)) `
    -Message 'It was stopped at the limit, well before its sleep ended'
Assert-That -Condition ($hung.Output -contains 'starting') -Message 'What it had printed by then is kept'
Assert-That -Condition (($hung.Output -join "`n") -like "*Stopped after $limit seconds*") `
    -Message 'and the output says why it ended'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that prints a tally with a failure, then hangs on its way out
$lateHangWrapper = New-FakeWrapper -Directory $sandbox `
    -Body "Write-Host '3 passed, 1 failed'`nStart-Sleep -Seconds $sleep"

# Act
$lateHung = Invoke-TestFileProcess -File $testFile -Name 'LateHang' -SourceRoot $sourceRoot `
    -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $lateHangWrapper -TimeoutSeconds $limit

# Assert
Assert-Equal -Expected $true -Actual $lateHung.TimedOut -Message 'A file that hangs after its tally is still timed out'
Assert-Equal -Expected $true -Actual $lateHung.Crashed `
    -Message 'and is a crash even though a tally with failures could be read'
Assert-Equal -Expected 1 -Actual $lateHung.Failed -Message 'while the tally it did print is kept'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a limit that cannot be
Assert-Throws -ScriptBlock {
    Invoke-TestFileProcess -File $testFile -Name 'Some' -SourceRoot $sourceRoot `
        -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $sawWrapper -TimeoutSeconds -1
} -MessageLike '*TimeoutSeconds*' -Message 'A negative -TimeoutSeconds is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that starts a process holding its output open, and ends
$grandchildWrapper = New-FakeWrapper -Directory $sandbox -Body @"
`$pwsh = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
Start-Process -FilePath `$pwsh -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds $sleep' -NoNewWindow
Write-Host '1 passed, 0 failed'
exit 0
"@

# Act
$held = Invoke-TestFileProcess -File $testFile -Name 'Held' -SourceRoot $sourceRoot `
    -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $grandchildWrapper -TimeoutSeconds $limit

# Assert
Assert-Equal -Expected $true -Actual $held.TimedOut `
    -Message 'A process the file left holding its output open is bounded by -TimeoutSeconds'
Assert-Equal -Expected $true -Actual $held.Crashed -Message 'and the file counts as crashed'
Assert-That -Condition ($held.Seconds -lt ($sleep - 20)) `
    -Message 'It was given up on at the limit, well before the process it left ended'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two source folders that exist, side by side
$sharedRoot = Join-Path $sandbox 'shared'
$sharedA = New-Item -ItemType Directory -Path (Join-Path $sharedRoot 'A')
$sharedB = New-Item -ItemType Directory -Path (Join-Path $sharedRoot 'B')
$whereWrapper = New-FakeWrapper -Directory $sandbox -Body @'
Write-Host "location=$((Get-Location).Path)"
Write-Host "pester=[$env:TESTRUNNER_PESTER_PATH]"
Write-Host "saw TestFile=$TestFile SourceRoot=$SourceRoot OutputPath=$OutputPath ResultPath=$ResultPath"
Write-Host '1 passed, 0 failed'
exit 0
'@

# Act
$shared = Invoke-TestFileProcess -File $testFile -Name 'Shared' -SourceRoot @($sharedA.FullName, $sharedB.FullName) `
    -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $whereWrapper
$missing = Invoke-TestFileProcess -File $testFile -Name 'Missing' -SourceRoot (Join-Path $sharedRoot 'C' 'D') `
    -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $whereWrapper

# Assert
Assert-That -Condition ($shared.Output -contains "location=$sharedRoot") `
    -Message 'The file runs in the deepest folder holding every -SourceRoot'
Assert-That -Condition ($missing.Output -contains "location=$sharedRoot") `
    -Message 'or in the nearest existing one, when -SourceRoot does not exist yet'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - PowerShell in the sandbox, the process somewhere else, every path
# given relative
$elsewhere = New-TestRunnerSandbox
$relativeWrapper = Split-Path -Leaf $whereWrapper

# Act
$relative = Use-SplitLocation -Location $sandbox -ProcessDirectory $elsewhere -ScriptBlock {
    Invoke-TestFileProcess -File 'Some.Tests.ps1' -Name 'Relative' -SourceRoot 'shared' `
        -Coverage -ReportPath 'report.xml' -ResultPath 'result.xml' -WrapperPath $relativeWrapper
}
$relativeText = $relative.Output -join "`n"

# Assert
Assert-Equal -Expected 1 -Actual $relative.Passed -Message 'A relative -WrapperPath is found in PowerShell''s location'
Assert-That -Condition $relativeText.Contains("TestFile=$testFile ") `
    -Message 'and every path reaches the wrapper made absolute against it'
Assert-That -Condition $relativeText.Contains("SourceRoot=$sharedRoot ") -Message 'including -SourceRoot'
Assert-That -Condition $relativeText.Contains("OutputPath=$reportPath ResultPath=$resultPath") `
    -Message 'and both report paths'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a Pester path inherited from this process, which a child must not see
$inherited = $env:TESTRUNNER_PESTER_PATH
$env:TESTRUNNER_PESTER_PATH = 'inherited'

# Act
try {
    $given = Invoke-TestFileProcess -File $testFile -Name 'Given' -SourceRoot $sourceRoot `
        -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $whereWrapper -PesterPath 'given-path'
    $none = Invoke-TestFileProcess -File $testFile -Name 'None' -SourceRoot $sourceRoot `
        -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $whereWrapper -PesterPath ''
    $loaded = Invoke-WithSeam -Module $module -Name 'Get-LoadedPesterPath' -Replacement { 'loaded-path' } -ScriptBlock {
        Invoke-TestFileProcess -File $testFile -Name 'Loaded' -SourceRoot $sourceRoot `
            -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $whereWrapper
    }
}
finally {
    $env:TESTRUNNER_PESTER_PATH = $inherited
}

# Assert
Assert-That -Condition ($given.Output -contains 'pester=[given-path]') `
    -Message '-PesterPath reaches the wrapper as TESTRUNNER_PESTER_PATH'
Assert-That -Condition ($none.Output -contains 'pester=[]') `
    -Message 'An empty -PesterPath leaves it unset, whatever this process has'
Assert-That -Condition ($loaded.Output -contains 'pester=[loaded-path]') `
    -Message 'Without -PesterPath, the Pester loaded in this session is handed on'

#───────────────────────────────────────────────────────────────────────────────
# Act - a wrapper that could not be started at all
$notStarted = Invoke-WithSeam -Module $module -Name 'Invoke-NativeRead' -Replacement {
    @{ Ok = $false; Started = $false; ExitCode = 127; Output = @('pwsh is gone'); ErrorOutput = @(); TimedOut = $false }
} -ScriptBlock {
    Invoke-TestFileProcess -File $testFile -Name 'NotStarted' -SourceRoot $sourceRoot `
        -Coverage -ReportPath $reportPath -ResultPath $resultPath -WrapperPath $whereWrapper
}

# Assert
Assert-Equal -Expected $true -Actual $notStarted.NotStarted `
    -Message 'A wrapper that could not start is marked as not started'
Assert-Equal -Expected $true -Actual $notStarted.Crashed -Message 'and counts as crashed'
Assert-Equal -Expected @('pwsh is gone') -Actual $notStarted.Output -Message 'with the reason as its output'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no -WrapperPath at all, so this exercises the module's own
# shipped default - a real file under real Pester coverage, not a fake wrapper,
# since the point is confirming the default actually exists and runs
$defaultReportPath = Join-Path $sandbox 'default-report.xml'
$defaultResultPath = Join-Path $sandbox 'default-result.xml'
$defaultFile = Join-Path $sandbox 'Default.Tests.ps1'
Set-Content -LiteralPath $defaultFile `
    -Value (Get-TestKitFileContent -Body "Assert-Equal -Expected 2 -Actual 2 -Message 'two'")

# Act
$defaultResult = Invoke-TestFileProcess `
    -File $defaultFile `
    -Name 'Default' `
    -SourceRoot $sharedRoot `
    -Coverage `
    -ReportPath $defaultReportPath `
    -ResultPath $defaultResultPath

# Assert
Assert-Equal -Expected $false -Actual $defaultResult.Crashed `
    -Message 'The default -WrapperPath runs the file without crashing'
Assert-Equal -Expected 1 -Actual $defaultResult.Passed `
    -Message 'The default -WrapperPath reports the file''s real tally'
Assert-That -Condition (Test-Path -LiteralPath $defaultReportPath) `
    -Message 'The default -WrapperPath writes a coverage report'
Assert-That -Condition (Test-Path -LiteralPath $defaultResultPath) `
    -Message 'The default -WrapperPath writes a JUnit result'

# Cleanup
Remove-TestRunnerSandbox -Path $directRoot
Remove-TestRunnerSandbox -Path $sandbox
Remove-TestRunnerSandbox -Path $elsewhere

exit (Complete-TestRun)
