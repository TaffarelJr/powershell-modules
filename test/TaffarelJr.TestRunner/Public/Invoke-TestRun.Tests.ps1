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

function Get-RunName {
    <#
    .SYNOPSIS
        Returns the display names in a run's results, sorted and comma-joined,
        since results come back in whichever order the files finished.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Run
    )

    return (@($Run.Results | ForEach-Object Name) | Sort-Object) -join ', '
}

$module = Get-Module -Name 'TaffarelJr.TestRunner'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one passing TestKit file in a scratch tree, run with no -Coverage and no report folders
$plainRoot = New-TestRunnerSandbox
$plainTests = Join-Path $plainRoot 'test'
$plainSource = Join-Path $plainRoot 'src'
New-Item -ItemType Directory -Path $plainTests, $plainSource | Out-Null
Set-Content -LiteralPath (Join-Path $plainTests 'Plain.Tests.ps1') `
    -Value (Get-TestKitFileContent -Body "Assert-That -Condition `$true -Message 'passes'")

# Act
$plainRun = $null
$plainLines = @(Get-HostOutput { $script:plainRun = Invoke-TestRun -Path $plainTests -SourceRoot $plainSource })
$plainText = $plainLines -join "`n"

# Assert
Assert-Equal -Expected 1 -Actual @($plainRun.Results).Count -Message 'A run without -Coverage runs the file it found'
Assert-Equal -Expected 0 -Actual $plainRun.ExitCode -Message 'and exits 0 when it passes'
Assert-That -Condition $plainText.Contains('No coverage or result reports were written: pass -Coverage for them.') `
    -Message 'and says that no report was written, and how to get one'
Assert-That -Condition $plainText.Contains("Running 1 test file(s), up to $([Environment]::ProcessorCount) at a time") `
    -Message 'and by default runs as many files at once as there are processors'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the report folders and a wrapper named, with no -Coverage to use them
$ignoredWrapper = Join-Path $plainRoot 'no-wrapper.ps1'

# Act - with Pester neither checked nor looked up, which would throw here
$ignoredRun = Invoke-WithSeam -Module $module -Name 'Assert-RequiredModule' `
    -Replacement { throw 'Pester was checked without -Coverage' } `
    -ScriptBlock {
        Invoke-WithSeam -Module $module -Name 'Get-LoadedPesterPath' `
            -Replacement { throw 'Pester was looked up without -Coverage' } `
            -ScriptBlock {
                Invoke-TestRun -Path $plainTests -SourceRoot $plainSource -WrapperPath $ignoredWrapper `
                    -OutputPath (Join-Path $plainRoot 'coverage') -ResultsPath (Join-Path $plainRoot 'results') 6>$null
            }
    }
$plainFolders = @(Get-ChildItem -LiteralPath $plainRoot -Directory | ForEach-Object Name | Sort-Object)

# Assert
Assert-Equal -Expected 0 -Actual $ignoredRun.ExitCode `
    -Message 'Without -Coverage, Pester is neither checked nor looked up'
Assert-Equal -Expected @('src', 'test') -Actual $plainFolders `
    -Message 'and the report paths and the wrapper are ignored: no report folder is made'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that leaves a mark when it runs
$guardMarker = Join-Path $plainRoot 'guard-ran.txt'
$guardTests = Join-Path $plainRoot 'guard-test'
New-Item -ItemType Directory -Path $guardTests | Out-Null
Set-Content -LiteralPath (Join-Path $guardTests 'Guard.Tests.ps1') -Value @"
Set-Content -LiteralPath '$guardMarker' -Value 'ran'
exit 0
"@

# Act / Assert
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path $guardTests -SourceRoot $plainSource -Coverage -ResultsPath (Join-Path $plainRoot 'results')
} -MessageLike '*-Coverage needs -OutputPath and -ResultsPath*' `
    -Message '-Coverage without -OutputPath is refused'
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path $guardTests -SourceRoot $plainSource -Coverage -OutputPath (Join-Path $plainRoot 'coverage')
} -MessageLike '*-Coverage needs -OutputPath and -ResultsPath*' `
    -Message 'and so is -Coverage without -ResultsPath'
Assert-That -Condition (-not (Test-Path -LiteralPath $guardMarker)) -Message 'before any file runs'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two modules' source, and a test under the first one's folder that calls it
$scopeRoot = New-TestRunnerSandbox
$scopeSource = Join-Path $scopeRoot 'src'
$scopeTests = Join-Path $scopeRoot 'test'
$scopeA = Join-Path $scopeSource 'TaffarelJr.A'
$scopeB = Join-Path $scopeSource 'TaffarelJr.B'
New-Item -ItemType Directory -Path $scopeA, $scopeB, (Join-Path $scopeTests 'TaffarelJr.A') | Out-Null
Set-Content -LiteralPath (Join-Path $scopeA 'A.psm1') -Value 'function Get-A { return 1 }'
Set-Content -LiteralPath (Join-Path $scopeB 'B.psm1') -Value 'function Get-B { return 2 }'
$scopeBody = Get-TestKitFileContent -Body @"
Import-Module '$(Join-Path $scopeA 'A.psm1')' -Force
Assert-Equal -Expected 1 -Actual (Get-A) -Message 'Get-A returns 1'
"@
Set-Content -LiteralPath (Join-Path $scopeTests 'TaffarelJr.A' 'Get-A.Tests.ps1') -Value $scopeBody

# Act
$scopeRun = Invoke-TestRun -Path $scopeTests -SourceRoot $scopeSource -Coverage `
    -OutputPath (Join-Path $scopeRoot 'coverage') -ResultsPath (Join-Path $scopeRoot 'results') 6>$null
$scopeReportPath = Join-Path $scopeRoot 'coverage' 'TaffarelJr.A' 'Get-A.cobertura.xml'
$scopeReport = [xml](Get-Content -LiteralPath $scopeReportPath -Raw)
$scopeFiles = @($scopeReport.SelectNodes('//class') | ForEach-Object { $_.GetAttribute('filename') })

# Assert
Assert-Equal -Expected 0 -Actual $scopeRun.ExitCode `
    -Message 'A file under a module''s test folder passes under -Coverage'
Assert-Equal -Expected 1 -Actual @($scopeFiles | Where-Object { $_ -like '*A.psm1' }).Count `
    -Message 'and its coverage report names that module''s source'
Assert-Equal -Expected 0 -Actual @($scopeFiles | Where-Object { $_ -like '*B.psm1' }).Count `
    -Message 'and not the source of a module whose tests are not running'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake wrapper standing in for Invoke-TestFile.ps1, which does
# whatever the test file's own name says: pass, fail, lie, go quiet, or hang
$sandbox = New-TestRunnerSandbox
$testRoot = Join-Path $sandbox 'test'
$outputRoot = Join-Path $sandbox 'coverage'
$resultsRoot = Join-Path $sandbox 'results'
$sourceRoot = Join-Path $sandbox 'src'
New-Item -ItemType Directory -Path $sourceRoot | Out-Null
New-TestFileStub -Directory $testRoot -Name 'One' | Out-Null
New-TestFileStub -Directory $testRoot -Name 'Two' | Out-Null
$wrapper = New-FakeWrapper -Directory $sandbox -Body @'
switch -Wildcard ([IO.Path]::GetFileName($TestFile)) {
    'Liar*'   { Write-Host 'a case went wrong'; Write-Host '3 passed, 2 failed'; exit 0 }
    'Skip*'   { Write-Host 'skipped - not on this machine'; Write-Host ''; Write-Host '0 passed, 0 failed'; exit 0 }
    'Silent*' { Write-Host 'went wrong before any tally'; exit 0 }
    'Fail*'   { Write-Host 'the failing detail'; Write-Host '1 passed, 1 failed'; exit 1 }
    'Hang*'   { Write-Host 'starting'; Start-Sleep -Seconds 120; Write-Host '1 passed, 0 failed'; exit 0 }
    default   { Write-Host 'chatter from a passing file'; Write-Host '1 passed, 0 failed'; exit 0 }
}
'@

# Act
$run = $null
$lines = @(Get-HostOutput {
        $script:run = Invoke-TestRun -Path $testRoot -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
            -ResultsPath $resultsRoot `
            -WrapperPath $wrapper `
            -ThrottleLimit 2
    })
$text = $lines -join "`n"

# Assert
Assert-Equal -Expected 2 -Actual @($run.Results).Count -Message 'Runs every discovered test file'
Assert-Equal -Expected 0 -Actual $run.ExitCode -Message 'Exits 0 when every file passes'
Assert-Equal -Expected 'One, Two' -Actual (Get-RunName -Run $run) `
    -Message 'There is a result for each file, named for it'
Assert-That -Condition $text.Contains('Running 2 test file(s), up to 2 at a time') `
    -Message 'Says what it is about to do, so a long first wait is not silence'
Assert-That -Condition ($text -like '*2 file(s) - 2 passed - 0 failed - 0 crashed - 0 skipped*') `
    -Message 'Ends with the summary'
Assert-That -Condition (-not $text.Contains('chatter from a passing file')) `
    -Message 'A passing file''s output is not printed'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same, asking to see every file's output
$shown = @(Get-HostOutput {
        $null = Invoke-TestRun -Path $testRoot -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
            -ResultsPath $resultsRoot `
            -WrapperPath $wrapper `
            -ShowOutput
    })

# Assert
Assert-That -Condition (($shown -join "`n").Contains('chatter from a passing file')) `
    -Message '-ShowOutput prints a passing file''s output too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - no matching files at all
$emptyRoot = New-TestRunnerSandbox
$emptyRun = $null
$emptyLines = @(Get-HostOutput {
        $script:emptyRun = Invoke-TestRun -Path $emptyRoot -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
            -ResultsPath $resultsRoot `
            -WrapperPath $wrapper
    })

# Assert
Assert-Equal -Expected 0 -Actual @($emptyRun.Results).Count -Message 'No matching files means no results'
Assert-Equal -Expected 1 -Actual $emptyRun.ExitCode -Message 'An empty run exits 1, distinct from a clean pass'
Assert-That -Condition (($emptyLines -join "`n") -like "*No test file matches '*.Tests.ps1'*") `
    -Message 'and says that nothing matched'
Assert-That -Condition (-not ($emptyLines -join "`n").Contains('after excluding')) `
    -Message 'without naming exclusions that were never given'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Path narrowed to one subfolder, -TestRoot kept at the real root
$moduleFolder = Join-Path $testRoot 'TaffarelJr.Example'
New-TestFileStub -Directory $moduleFolder -Name 'Three' | Out-Null
$scopedRun = Invoke-TestRun -Path $moduleFolder -TestRoot $testRoot -SourceRoot $sourceRoot -Coverage `
    -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper 6>$null

# Assert
Assert-Equal -Expected 1 -Actual @($scopedRun.Results).Count -Message 'A narrowed -Path only searches that subfolder'
Assert-Equal -Expected 'TaffarelJr.Example/Three' -Actual $scopedRun.Results[0].Name `
    -Message '-TestRoot keeps the full display name even when -Path is narrowed to a subfolder'
Assert-That -Condition (Test-Path -LiteralPath (Join-Path $outputRoot 'TaffarelJr.Example') -PathType Container) `
    -Message 'and its reports go in the folder a full run would use'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a second, unrelated folder
$secondFolder = New-TestRunnerSandbox
New-TestFileStub -Directory (Join-Path $secondFolder 'test') -Name 'Four' | Out-Null
$secondTests = Join-Path $secondFolder 'test'

# Act - -Path given as a real multi-element array, with -TestRoot above both
$multiRun = Invoke-TestRun -Path @($testRoot, $secondTests) -TestRoot ([Path]::GetTempPath()) `
    -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper 6>$null

# Assert - testRoot itself now has One, Two, and TaffarelJr.Example/Three from
# the earlier cases, plus Four from the second folder
Assert-Equal -Expected 4 -Actual @($multiRun.Results).Count `
    -Message 'Every folder in a multi-element -Path is searched, results combined'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same two folders as one comma-joined -Path value, as a caller
# invoked externally (pwsh -File, a CI workflow step) would have to send them
$commaRun = Invoke-TestRun -Path "$testRoot,$secondTests" -TestRoot ([Path]::GetTempPath()) `
    -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper 6>$null

# Assert
Assert-Equal -Expected 4 -Actual @($commaRun.Results).Count `
    -Message 'A single comma-joined -Path value is split and both folders are searched'

#───────────────────────────────────────────────────────────────────────────────
# Act - a folder together with one of its own subfolders
$nestedRun = Invoke-TestRun -Path @($testRoot, $moduleFolder) -TestRoot $testRoot `
    -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper 6>$null

# Assert
Assert-Equal -Expected 3 -Actual @($nestedRun.Results).Count `
    -Message 'A file under two of the folders in -Path is run once, not twice'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a unit test file beside a *.Live one
$tierRoot = Join-Path $sandbox 'tiers'
New-TestFileStub -Directory $tierRoot -Name 'Get-A' | Out-Null
New-TestFileStub -Directory $tierRoot -Name 'Get-A.Live' | Out-Null

# Act
$excludedRun = Invoke-TestRun -Path $tierRoot -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
    -ResultsPath $resultsRoot -WrapperPath $wrapper -Exclude '*.Live' 6>$null

# Assert
Assert-Equal -Expected 'Get-A' -Actual (Get-RunName -Run $excludedRun) `
    -Message '-Exclude keeps the files it matches out of the run'

#───────────────────────────────────────────────────────────────────────────────
# Act - two patterns sent as one comma-joined value, as a caller invoked externally has to send them
$commaExcludedRun = Invoke-TestRun -Path $tierRoot -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
    -ResultsPath $resultsRoot -WrapperPath $wrapper -Exclude 'X.Live,Y.Live' 6>$null

# Assert
Assert-Equal -Expected 'Get-A, Get-A.Live' -Actual (Get-RunName -Run $commaExcludedRun) `
    -Message 'A single comma-joined -Exclude value is split in two, and neither pattern matches'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder holding nothing but integration files
$liveRoot = Join-Path $sandbox 'live-only'
New-TestFileStub -Directory $liveRoot -Name 'Get-B.Live' | Out-Null

# Act
$noneLeftRun = $null
$noneLeftLines = @(Get-HostOutput {
        $script:noneLeftRun = Invoke-TestRun -Path $liveRoot -SourceRoot $sourceRoot -Coverage `
            -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper -Exclude '*.Live', '*.Contract'
    })

# Assert
Assert-Equal -Expected 1 -Actual $noneLeftRun.ExitCode `
    -Message 'A run whose files are all excluded exits 1, as an empty one does'
Assert-That -Condition (($noneLeftLines -join "`n").Contains("under $liveRoot, after excluding *.Live, *.Contract")) `
    -Message 'and names the exclusions in the warning, so a missing file is not a mystery'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder whose own name has a comma in it
$commaFolder = Join-Path $sandbox 'Doe, John'
New-TestFileStub -Directory $commaFolder -Name 'Five' | Out-Null

# Act
$commaFolderRun = Invoke-TestRun -Path $commaFolder -SourceRoot $sourceRoot -Coverage `
    -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper 6>$null

# Assert
Assert-Equal -Expected 'Five' -Actual (Get-RunName -Run $commaFolderRun) `
    -Message 'A folder with a comma in its name is searched, not split in two'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - -Path with more than one folder requires -TestRoot explicitly
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path @($testRoot, $secondTests) -SourceRoot $sourceRoot `
        -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper
} -MessageLike '*-TestRoot is required*' -Message '-Path with more than one folder throws without an explicit -TestRoot'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - -Path that names nothing
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path ',' -SourceRoot $sourceRoot -OutputPath $outputRoot -ResultsPath $resultsRoot `
        -WrapperPath $wrapper
} -MessageLike '*-Path names no folder*' -Message 'A -Path that is only commas says so, instead of blaming -TestRoot'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a test file outside -TestRoot
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path $secondTests -TestRoot $testRoot -SourceRoot $sourceRoot `
        -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper
} -MessageLike '*Four.Tests.ps1*not under -TestRoot*' `
    -Message 'A file outside -TestRoot throws, naming it, before anything runs'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a throttle limit that cannot work
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path $testRoot -SourceRoot $sourceRoot -OutputPath $outputRoot -ResultsPath $resultsRoot `
        -WrapperPath $wrapper `
        -ThrottleLimit 0
} -MessageLike '*ThrottleLimit*' -Message 'A -ThrottleLimit of 0 is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one file of each kind that is not a clean pass
$mixedRoot = Join-Path $sandbox 'mixed'
foreach ($name in 'Pass', 'FailOne', 'LiarOne', 'SilentOne') {
    New-TestFileStub -Directory $mixedRoot -Name $name | Out-Null
}

# Act
$mixedRun = $null
$mixedLines = @(Get-HostOutput {
        $script:mixedRun = Invoke-TestRun -Path $mixedRoot -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
            -ResultsPath $resultsRoot `
            -WrapperPath $wrapper
    })
$mixedText = $mixedLines -join "`n"

# Assert
Assert-Equal -Expected 4 -Actual @($mixedRun.Results).Count -Message 'Every file has a result'
Assert-Equal -Expected 3 -Actual $mixedRun.ExitCode `
    -Message 'The exit code is the number of files that failed: one that failed, one that lied, one that went quiet'
Assert-That -Condition $mixedText.Contains('the failing detail') -Message 'A failing file''s output is printed'
Assert-That -Condition $mixedText.Contains('a case went wrong') `
    -Message 'so is the output of a file that reported failures yet exited 0'
Assert-That -Condition $mixedText.Contains('went wrong before any tally') `
    -Message 'and the output of a file that crashed with exit 0'
Assert-That -Condition (-not $mixedText.Contains('chatter from a passing file')) -Message 'but not a passing file''s'
Assert-That -Condition ($mixedText -like '*4 file(s) - 5 passed - 3 failed - 1 crashed - 0 skipped*') `
    -Message 'The summary counts all of it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that skips itself, beside one that passes
$skipRoot = Join-Path $sandbox 'skip'
New-TestFileStub -Directory $skipRoot -Name 'SkipHere' | Out-Null
New-TestFileStub -Directory $skipRoot -Name 'Fine' | Out-Null

# Act
$skipRun = $null
$skipLines = @(Get-HostOutput {
        $script:skipRun = Invoke-TestRun -Path $skipRoot -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
            -ResultsPath $resultsRoot `
            -WrapperPath $wrapper
    })
$skipText = $skipLines -join "`n"

# Assert
Assert-Equal -Expected 0 -Actual $skipRun.ExitCode -Message 'A skipped file does not fail the run'
Assert-That -Condition ($skipText -like '*⏭*SkipHere*skipped - not on this machine*') `
    -Message 'It is shown as skipped, with its reason'
Assert-That -Condition ($skipText -like '*2 file(s) - 1 passed - 0 failed - 0 crashed - 1 skipped*') `
    -Message 'and counted apart in the summary'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that never finishes, alone, so no other file has to finish
# within the limit; it sleeps 120 s, far past it
$hangRoot = Join-Path $sandbox 'hang'
New-TestFileStub -Directory $hangRoot -Name 'HangForever' | Out-Null

# Act
$hangRun = $null
$clock = [Diagnostics.Stopwatch]::StartNew()
$hangLines = @(Get-HostOutput {
        $script:hangRun = Invoke-TestRun -Path $hangRoot -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
            -ResultsPath $resultsRoot `
            -WrapperPath $wrapper `
            -TimeoutSeconds 20
    })
$clock.Stop()
$hung = $hangRun.Results | Where-Object Name -EQ 'HangForever'

# Assert
Assert-Equal -Expected 1 -Actual $hangRun.ExitCode -Message 'A file that runs out of time fails the run'
Assert-Equal -Expected $true -Actual $hung.TimedOut -Message 'The file is marked as timed out'
Assert-That -Condition ($clock.Elapsed.TotalSeconds -lt 100) `
    -Message 'The run did not wait for the file to finish on its own'
Assert-That -Condition (($hangLines -join "`n") -like '*timed out*') -Message 'The verdict printed says it timed out'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a -SourceRoot that makes Invoke-TestFileProcess throw inside every
# worker, a folder whose own name holds the list separator
$badSourceRoot = Join-Path $sandbox "left$([Path]::PathSeparator)right"
New-Item -ItemType Directory -Path $badSourceRoot | Out-Null

# Act
$brokenRun = $null
$brokenLines = @(Get-HostOutput {
        $script:brokenRun = Invoke-TestRun -Path $testRoot -SourceRoot $badSourceRoot -Coverage `
            -OutputPath $outputRoot `
            -ResultsPath $resultsRoot `
            -WrapperPath $wrapper
    })
$brokenResult = $brokenRun.Results | Where-Object Name -EQ 'One'

# Assert - $testRoot holds One, Two, and TaffarelJr.Example/Three by now
Assert-Equal -Expected 3 -Actual @($brokenRun.Results).Count `
    -Message 'A file whose worker failed is still in the results, not silently dropped'
Assert-Equal -Expected 3 -Actual $brokenRun.ExitCode `
    -Message 'and each counts as a failed file, so the run does not pass'
Assert-Equal -Expected $true -Actual $brokenResult.Crashed -Message 'It is reported as crashed'
Assert-Equal -Expected $true -Actual $brokenResult.NotStarted -Message 'and as not started, since no process ran it'
Assert-That -Condition (($brokenResult.Output -join "`n") -like '*-SourceRoot entry*') `
    -Message 'with the reason the worker gave'
Assert-That -Condition (($brokenLines -join "`n") -like '*❌*One*not started*') `
    -Message 'The verdict says the file was not started, not that it exited 1'
Assert-That -Condition (($brokenLines -join "`n") -like '*-SourceRoot entry*') `
    -Message 'and the reason is printed, since a failed file''s output is'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module the workers need, which cannot be imported
$missingModule = Join-Path $sandbox 'nowhere' 'Missing.psd1'

# Act
$importRun = Invoke-WithSeam -Module $module -Name 'Get-WorkerModulePath' -Replacement { $missingModule } -ScriptBlock {
    Invoke-TestRun -Path $mixedRoot -Filter 'Pass' -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
        -ResultsPath $resultsRoot -WrapperPath $wrapper 6>$null
}

# Assert
Assert-Equal -Expected $true -Actual $importRun.Results[0].NotStarted `
    -Message 'A worker that cannot import what it needs reports the file as not started'
Assert-That -Condition (($importRun.Results[0].Output -join "`n") -like '*Missing.psd1*') `
    -Message 'naming the module it could not import'
Assert-Equal -Expected 1 -Actual $importRun.ExitCode -Message 'and the file fails the run'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a -SourceRoot that names nothing, or no folder
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path $testRoot -SourceRoot ',' -OutputPath $outputRoot -ResultsPath $resultsRoot `
        -WrapperPath $wrapper
} -MessageLike '*-SourceRoot names no folder*' `
    -Message 'A -SourceRoot that is only commas is refused before any file runs'

# Act
$typo = Join-Path $sandbox 'srcc'

# Assert
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path $testRoot -SourceRoot $typo -OutputPath $outputRoot -ResultsPath $resultsRoot `
        -WrapperPath $wrapper
} -MessageLike "*-SourceRoot '$typo' is not an existing folder*" `
    -Message 'A -SourceRoot that does not exist is refused, naming it'

#───────────────────────────────────────────────────────────────────────────────
# Act - a -Path that is a file, not a folder
$oneFile = Join-Path $testRoot 'One.Tests.ps1'

# Assert
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path $oneFile -SourceRoot $sourceRoot -OutputPath $outputRoot -ResultsPath $resultsRoot `
        -WrapperPath $wrapper
} -MessageLike "*-Path '$oneFile' is not an existing folder*" `
    -Message 'A -Path naming a file is refused rather than given the display name "."'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the test and source folders reached through a drive of their own,
# global so the module's own scope sees it
$null = New-PSDrive -Name 'TestRunnerProject' -PSProvider FileSystem -Root $sandbox -Scope Global

# Act
try {
    $driveRun = Invoke-TestRun -Path 'TestRunnerProject:\test' -SourceRoot 'TestRunnerProject:\src' -Coverage `
        -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper 6>$null
}
finally {
    Remove-PSDrive -Name 'TestRunnerProject' -Scope Global
}

# Assert
Assert-Equal -Expected 'One, TaffarelJr.Example/Three, Two' -Actual (Get-RunName -Run $driveRun) `
    -Message 'Folders on a PowerShell drive are searched and named like any other'
Assert-Equal -Expected 0 -Actual $driveRun.ExitCode -Message 'and their files run'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - PowerShell in the sandbox, the process somewhere else, every path
# given relative
$elsewhere = New-TestRunnerSandbox
$relativeWrapper = Split-Path -Leaf $wrapper

# Act
$relativeRun = Use-SplitLocation -Location $sandbox -ProcessDirectory $elsewhere -ScriptBlock {
    Invoke-TestRun -Path 'test' -SourceRoot 'src' -Coverage -OutputPath 'relative-coverage' `
        -ResultsPath 'relative-results' -WrapperPath $relativeWrapper 6>$null
}

# Assert
Assert-Equal -Expected 0 -Actual $relativeRun.ExitCode `
    -Message 'Relative paths are relative to PowerShell''s location, not the process''s'
$relativeReports = Join-Path $sandbox 'relative-coverage' 'TaffarelJr.Example'
Assert-That -Condition (Test-Path -LiteralPath $relativeReports -PathType Container) `
    -Message 'and the reports go there too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the console in some other encoding than UTF-8
$original = [Console]::OutputEncoding
$other = [Text.Encoding]::GetEncoding(437)
[Console]::OutputEncoding = $other

# Act
$null = Get-HostOutput {
    $null = Invoke-TestRun -Path $testRoot -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
        -ResultsPath $resultsRoot -WrapperPath $wrapper
}
$afterRun = [Console]::OutputEncoding.CodePage
$null = Get-HostOutput {
    $null = Invoke-TestRun -Path $emptyRoot -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
        -ResultsPath $resultsRoot -WrapperPath $wrapper
}
$afterEmpty = [Console]::OutputEncoding.CodePage

# Act / Assert
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path $secondTests -TestRoot $testRoot -SourceRoot $sourceRoot -Coverage `
        -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper
} -MessageLike '*not under -TestRoot*' -Message 'A run that throws part-way'

# Act
$afterThrow = [Console]::OutputEncoding.CodePage
[Console]::OutputEncoding = $original

# Assert
Assert-Equal -Expected $other.CodePage -Actual $afterRun -Message 'The console''s encoding is put back after the run'
Assert-Equal -Expected $other.CodePage -Actual $afterEmpty -Message 'and after a run that found no file'
Assert-Equal -Expected $other.CodePage -Actual $afterThrow -Message 'and after a run that threw part-way'

#───────────────────────────────────────────────────────────────────────────────
# Act - a host with no console to set the encoding on
$noConsoleRun = Invoke-WithSeam -Module $module -Name 'Set-ConsoleEncoding' -Replacement {
    throw [IO.IOException]::new('The handle is invalid.')
} -ScriptBlock {
    Invoke-TestRun -Path $testRoot -Filter 'One' -SourceRoot $sourceRoot -Coverage -OutputPath $outputRoot `
        -ResultsPath $resultsRoot -WrapperPath $wrapper 6>$null
}

# Assert
Assert-Equal -Expected 0 -Actual $noConsoleRun.ExitCode -Message 'A host with no console still runs the files'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no -WrapperPath at all, on a small TestKit file written for the case
$defaultRoot = Join-Path $sandbox 'default-test'
$defaultSource = Join-Path $sandbox 'default-src'
New-Item -ItemType Directory -Path $defaultRoot, $defaultSource | Out-Null
$defaultBody = Get-TestKitFileContent -Body "Assert-Equal -Expected 'a' -Actual 'a' -Message 'a is a'"
Set-Content -LiteralPath (Join-Path $defaultRoot 'Default.Tests.ps1') -Value $defaultBody
$defaultOutputRoot = Join-Path $sandbox 'default-coverage'
$defaultResultsRoot = Join-Path $sandbox 'default-results'

# Act
$defaultRun = $null
$defaultLines = @(Get-HostOutput {
        $script:defaultRun = Invoke-TestRun `
            -Path $defaultRoot `
            -SourceRoot $defaultSource `
            -Coverage `
            -OutputPath $defaultOutputRoot `
            -ResultsPath $defaultResultsRoot
    })
$defaultText = $defaultLines -join "`n"
$coberturaReports = @(Get-ChildItem -LiteralPath $defaultOutputRoot -Recurse -File -Filter '*.cobertura.xml')
$junitReports = @(Get-ChildItem -LiteralPath $defaultResultsRoot -Recurse -File -Filter '*.junit.xml')

# Assert
Assert-Equal -Expected 1 -Actual @($defaultRun.Results).Count `
    -Message 'The default -WrapperPath still discovers and runs the matching file'
Assert-Equal -Expected 0 -Actual $defaultRun.ExitCode `
    -Message 'The default -WrapperPath reports a clean pass for a real, passing file'
Assert-Equal -Expected 1 -Actual $defaultRun.Results[0].Passed -Message 'with the file''s own tally'
Assert-Equal -Expected 1 -Actual $coberturaReports.Count -Message 'With -Coverage, the file gets one coverage report'
Assert-Equal -Expected 1 -Actual $junitReports.Count -Message 'and one result report'
Assert-That -Condition ($defaultText.Contains("Coverage reports in $defaultOutputRoot")) `
    -Message 'and the run says where the coverage reports are'
Assert-That -Condition ($defaultText.Contains("Test results in $defaultResultsRoot")) `
    -Message 'and where the results are'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a separate session that has a Pester of its own loaded by its path,
# on no module path, running the default wrapper
$pwshPath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$fakePester = New-FakePester -Directory (Join-Path $sandbox 'pester-by-path') -Version '5.4.0'
$childScript = Join-Path $sandbox 'Run-WithFakePester.ps1'
$childImports = foreach ($name in 'Tally', 'ConsoleOutput', 'ProcessInvocation', 'RequiredModules', 'TestRunner') {
    "Import-Module '$(Join-Path $repoRoot 'src' "TaffarelJr.$name" "TaffarelJr.$name.psd1")'"
}
Set-Content -LiteralPath $childScript -Value @(
    $childImports
    "Import-Module '$fakePester'"
    "`$run = Invoke-TestRun -Path '$defaultRoot' -SourceRoot '$defaultSource' -Coverage " +
    "-OutputPath '$defaultOutputRoot' -ResultsPath '$defaultResultsRoot' -ShowOutput"
    'exit $run.ExitCode'
)

# Act
$child = Invoke-NativeRead -Command $pwshPath -Arguments @('-NoProfile', '-NonInteractive', '-File', $childScript)

# Assert
Assert-That -Condition (($child.Output -join "`n") -like '*fake Pester 5.4.0 loaded*') `
    -Message 'Every file runs under the Pester the session loaded by its path'

# Cleanup
Remove-TestRunnerSandbox -Path $sandbox
Remove-TestRunnerSandbox -Path $emptyRoot
Remove-TestRunnerSandbox -Path $secondFolder
Remove-TestRunnerSandbox -Path $elsewhere
Remove-TestRunnerSandbox -Path $plainRoot
Remove-TestRunnerSandbox -Path $scopeRoot

exit (Complete-TestRun)
