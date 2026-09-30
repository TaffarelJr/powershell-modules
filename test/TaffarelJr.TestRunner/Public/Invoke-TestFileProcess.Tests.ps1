#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force

# Arrange - a fake wrapper standing in for Invoke-TestFile.ps1,
# so this test exercises Invoke-TestFileProcess's own
# process-spawning and output-parsing logic
# without needing real Pester coverage machinery
$fakeWrapper = Join-Path ([System.IO.Path]::GetTempPath()) "$([guid]::NewGuid()).ps1"
@'
param([string]$TestFile, [string]$SourceRoot, [string]$OutputPath, [string]$ResultPath)
Write-Host "saw TestFile=$TestFile SourceRoot=$SourceRoot OutputPath=$OutputPath ResultPath=$ResultPath"
Write-Host '2 passed, 1 failed'
exit 1
'@ | Set-Content -LiteralPath $fakeWrapper

# Act
$result = Invoke-TestFileProcess `
    -File 'C:\fake\Some.Tests.ps1' `
    -Name 'Some' `
    -SourceRoot 'C:\fake\src' `
    -ReportPath 'C:\fake\report.xml' `
    -ResultPath 'C:\fake\result.xml' `
    -WrapperPath $fakeWrapper

# Assert
Assert-Equal -Expected 'Some' -Actual $result.Name -Message 'The result carries the given display name'
Assert-Equal -Expected 2 -Actual $result.Passed -Message "Reads the passed count from the wrapper's output"
Assert-Equal -Expected 1 -Actual $result.Failed -Message "Reads the failed count from the wrapper's output"
Assert-Equal -Expected 1 -Actual $result.ExitCode -Message "Captures the wrapper's own exit code"
Assert-That -Condition (-not $result.Crashed) -Message 'A real tally with a matching failed count is not a crash'
Assert-That -Condition (($result.Output -join "`n") -like '*TestFile=C:\fake\Some.Tests.ps1*') -Message 'The wrapper is invoked with the given TestFile'
Assert-That -Condition (($result.Output -join "`n") -like '*SourceRoot=C:\fake\src*') -Message 'The wrapper is invoked with the given SourceRoot'
Assert-That -Condition (($result.Output -join "`n") -like '*ResultPath=C:\fake\result.xml*') -Message 'The wrapper is invoked with the given ResultPath'
Assert-That -Condition ($result.Seconds -ge 0) -Message 'Timing is captured as a non-negative number'

# Cleanup
Remove-Item -LiteralPath $fakeWrapper -Force

exit (Complete-TestRun)
