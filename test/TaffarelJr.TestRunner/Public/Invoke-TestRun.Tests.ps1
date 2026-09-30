#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake wrapper that always reports one pass,
# standing in for Invoke-TestFile.ps1
# so this test exercises discovery + orchestration + reporting
# without needing real Pester coverage machinery
$testRoot = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$outputRoot = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$resultsRoot = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
'' | Set-Content -LiteralPath (Join-Path $testRoot 'One.Tests.ps1')
'' | Set-Content -LiteralPath (Join-Path $testRoot 'Two.Tests.ps1')

$fakeWrapper = Join-Path ([Path]::GetTempPath()) "$([Guid]::NewGuid()).ps1"
@'
param([string]$TestFile, [string]$SourceRoot, [string]$OutputPath, [string]$ResultPath)
Write-Host '1 passed, 0 failed'
exit 0
'@ | Set-Content -LiteralPath $fakeWrapper

# Act
$run = Invoke-TestRun -Path $testRoot -SourceRoot 'C:\fake\src' -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $fakeWrapper -ThrottleLimit 2

# Assert
Assert-Equal -Expected 2 -Actual $run.Results.Count -Message 'Runs every discovered test file'
Assert-Equal -Expected 0 -Actual $run.ExitCode -Message 'Exits 0 when every file passes'
Assert-That -Condition (($run.Results | ForEach-Object Name) -contains 'One') -Message 'One of the results is for One.Tests.ps1'
Assert-That -Condition (($run.Results | ForEach-Object Name) -contains 'Two') -Message 'The other result is for Two.Tests.ps1'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - no matching files at all
$emptyRoot = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $emptyRoot -Force | Out-Null
$emptyRun = Invoke-TestRun -Path $emptyRoot -SourceRoot 'C:\fake\src' -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $fakeWrapper

# Assert
Assert-Equal -Expected 0 -Actual $emptyRun.Results.Count -Message 'No matching files means no results'
Assert-Equal -Expected 1 -Actual $emptyRun.ExitCode -Message 'An empty run exits 1, distinct from a clean pass'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Path narrowed to one subfolder, -TestRoot kept at the real root
$moduleFolder = Join-Path $testRoot 'TaffarelJr.Example'
New-Item -ItemType Directory -Path $moduleFolder -Force | Out-Null
'' | Set-Content -LiteralPath (Join-Path $moduleFolder 'Three.Tests.ps1')
$scopedRun = Invoke-TestRun -Path $moduleFolder -TestRoot $testRoot -SourceRoot 'C:\fake\src' -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $fakeWrapper

# Assert
Assert-Equal -Expected 1 -Actual $scopedRun.Results.Count -Message 'A narrowed -Path only searches that subfolder'
Assert-Equal -Expected 'TaffarelJr.Example/Three' -Actual $scopedRun.Results[0].Name -Message '-TestRoot keeps the full display name even when -Path is narrowed to a subfolder'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a second, unrelated folder
$secondFolder = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $secondFolder -Force | Out-Null
'' | Set-Content -LiteralPath (Join-Path $secondFolder 'Four.Tests.ps1')

# Act - -Path given as a real multi-element array
$multiRun = Invoke-TestRun -Path @($testRoot, $secondFolder) -TestRoot $testRoot `
    -SourceRoot 'C:\fake\src' -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $fakeWrapper

# Assert - testRoot itself now has One, Two, and TaffarelJr.Example/Three from
# the earlier cases, plus Four from the second folder
Assert-Equal -Expected 4 -Actual $multiRun.Results.Count -Message 'Every folder in a multi-element -Path is searched, results combined'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same two folders as one comma-joined -Path value, as a caller
# invoked externally (pwsh -File, a CI workflow step) would have to send them
$commaRun = Invoke-TestRun -Path "$testRoot,$secondFolder" -TestRoot $testRoot `
    -SourceRoot 'C:\fake\src' -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $fakeWrapper

# Assert
Assert-Equal -Expected 4 -Actual $commaRun.Results.Count -Message 'A single comma-joined -Path value is split and both folders are searched'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - -Path with more than one folder requires -TestRoot explicitly
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path @($testRoot, $secondFolder) -SourceRoot 'C:\fake\src' `
        -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $fakeWrapper
} -Message '-Path with more than one folder throws without an explicit -TestRoot'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no -WrapperPath at all, against this repo's own real test files,
# narrowed to one file so this stays as cheap as the other real-file cases
$defaultOutputRoot = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$defaultResultsRoot = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())

# Act
$defaultRun = Invoke-TestRun `
    -Path (Join-Path $repoRoot 'test/TaffarelJr.Tally') `
    -Filter 'Get-Tally' `
    -SourceRoot (Join-Path $repoRoot 'src') `
    -OutputPath $defaultOutputRoot `
    -ResultsPath $defaultResultsRoot

# Assert
Assert-Equal -Expected 1 -Actual $defaultRun.Results.Count -Message 'The default -WrapperPath still discovers and runs the matching file'
Assert-Equal -Expected 0 -Actual $defaultRun.ExitCode -Message 'The default -WrapperPath reports a clean pass for a real, passing file'

# Cleanup
Remove-Item -LiteralPath $testRoot, $emptyRoot, $secondFolder -Recurse -Force
Remove-Item -LiteralPath $fakeWrapper -Force
Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $resultsRoot -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $defaultOutputRoot -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $defaultResultsRoot -Recurse -Force -ErrorAction SilentlyContinue

exit (Complete-TestRun)
