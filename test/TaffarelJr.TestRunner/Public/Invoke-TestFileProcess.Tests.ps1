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
# Arrange - a fake wrapper standing in for Invoke-TestFile.ps1,
# so this test exercises Invoke-TestFileProcess's own
# process-spawning and output-parsing logic
# without needing real Pester coverage machinery
$fakeWrapper = Join-Path ([Path]::GetTempPath()) "$([Guid]::NewGuid()).ps1"
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

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - several -SourceRoot folders, which can only cross into the
# spawned process as one delimited string (see Expand-PathList's own doc
# comment for why a bare multi-element array does not survive that hop)
$multiResult = Invoke-TestFileProcess `
    -File 'C:\fake\Some.Tests.ps1' `
    -Name 'Some' `
    -SourceRoot @('C:\fake\src\A', 'C:\fake\src\B') `
    -ReportPath 'C:\fake\report.xml' `
    -ResultPath 'C:\fake\result.xml' `
    -WrapperPath $fakeWrapper

# Assert
Assert-That -Condition (($multiResult.Output -join "`n") -like "*SourceRoot=C:\fake\src\A$([Path]::PathSeparator)C:\fake\src\B*") `
    -Message 'Several -SourceRoot folders arrive at the wrapper joined by the platform path separator'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no -WrapperPath at all, so this exercises the module's own
# shipped default - a real file under real Pester coverage, not a fake wrapper,
# since the point is confirming the default actually exists and runs
$defaultReportPath = Join-Path ([Path]::GetTempPath()) "$([Guid]::NewGuid()).xml"
$defaultResultPath = Join-Path ([Path]::GetTempPath()) "$([Guid]::NewGuid()).xml"

# Act
$defaultResult = Invoke-TestFileProcess `
    -File (Join-Path $repoRoot 'test/TaffarelJr.Tally/Public/Get-Tally.Tests.ps1') `
    -Name 'Get-Tally' `
    -SourceRoot (Join-Path $repoRoot 'src') `
    -ReportPath $defaultReportPath `
    -ResultPath $defaultResultPath

# Assert
Assert-That -Condition (-not $defaultResult.Crashed) -Message 'The default -WrapperPath runs the file without crashing'
Assert-That -Condition ($defaultResult.Passed -gt 0) -Message 'The default -WrapperPath reports a real tally, not zero'
Assert-That -Condition (Test-Path -LiteralPath $defaultReportPath) -Message 'The default -WrapperPath writes a coverage report'
Assert-That -Condition (Test-Path -LiteralPath $defaultResultPath) -Message 'The default -WrapperPath writes a JUnit result'

# Cleanup
Remove-Item -LiteralPath $fakeWrapper -Force
Remove-Item -LiteralPath $defaultReportPath, $defaultResultPath -Force -ErrorAction SilentlyContinue

exit (Complete-TestRun)
