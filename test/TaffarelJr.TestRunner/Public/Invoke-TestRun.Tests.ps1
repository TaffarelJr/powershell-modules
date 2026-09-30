#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force

# Arrange - a fake wrapper that always reports one pass,
# standing in for Invoke-TestFile.ps1
# so this test exercises discovery + orchestration + reporting
# without needing real Pester coverage machinery
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
$outputRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
$resultsRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
'' | Set-Content -LiteralPath (Join-Path $testRoot 'One.Tests.ps1')
'' | Set-Content -LiteralPath (Join-Path $testRoot 'Two.Tests.ps1')

$fakeWrapper = Join-Path ([System.IO.Path]::GetTempPath()) "$([guid]::NewGuid()).ps1"
@'
param([string]$TestFile, [string]$SourceRoot, [string]$OutputPath, [string]$ResultPath)
Write-Host '1 passed, 0 failed'
exit 0
'@ | Set-Content -LiteralPath $fakeWrapper

# Act
$run = Invoke-TestRun -Path $testRoot -SourceRoot 'C:\fake\src' -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $fakeWrapper

# Assert
Assert-Equal -Expected 2 -Actual $run.Results.Count -Message 'Runs every discovered test file'
Assert-Equal -Expected 0 -Actual $run.ExitCode -Message 'Exits 0 when every file passes'
Assert-That -Condition (($run.Results | ForEach-Object Name) -contains 'One') -Message 'One of the results is for One.Tests.ps1'
Assert-That -Condition (($run.Results | ForEach-Object Name) -contains 'Two') -Message 'The other result is for Two.Tests.ps1'

# Arrange / Act - no matching files at all
$emptyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
New-Item -ItemType Directory -Path $emptyRoot -Force | Out-Null
$emptyRun = Invoke-TestRun -Path $emptyRoot -SourceRoot 'C:\fake\src' -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $fakeWrapper

# Assert
Assert-Equal -Expected 0 -Actual $emptyRun.Results.Count -Message 'No matching files means no results'
Assert-Equal -Expected 1 -Actual $emptyRun.ExitCode -Message 'An empty run exits 1, distinct from a clean pass'

# Cleanup
Remove-Item -LiteralPath $testRoot, $emptyRoot -Recurse -Force
Remove-Item -LiteralPath $fakeWrapper -Force
Remove-Item -LiteralPath $outputRoot -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $resultsRoot -Recurse -Force -ErrorAction SilentlyContinue

exit (Complete-TestRun)
