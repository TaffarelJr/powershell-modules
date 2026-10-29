#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Every case runs the real wrapper under real Pester, through
# Invoke-TestFileProcess, on a small test file written for the case.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'TestRunnerTestHelper.ps1')

function Invoke-WrappedFile {
    <#
    .SYNOPSIS
        Writes a test file with the given content and runs it through the real
        wrapper, with the given folders for coverage.
    .OUTPUTS
        The result from Invoke-TestFileProcess, with ReportPath and ResultPath
        added so a test can look at the reports.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Sandbox,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string[]]$SourceRoot,

        [int]$TimeoutSeconds,

        [string]$PesterPath
    )

    $file = Join-Path $Sandbox "$Name.Tests.ps1"
    Set-Content -LiteralPath $file -Value $Content
    $report = Join-Path $Sandbox "$Name.cobertura.xml"
    $junit = Join-Path $Sandbox "$Name.junit.xml"
    $options = @{}
    foreach ($option in 'TimeoutSeconds', 'PesterPath') {
        if ($PSBoundParameters.ContainsKey($option)) {
            $options[$option] = $PSBoundParameters[$option]
        }
    }

    $result = Invoke-TestFileProcess `
        -File $file `
        -Name $Name `
        -SourceRoot $SourceRoot `
        -Coverage `
        -ReportPath $report `
        -ResultPath $junit `
        @options
    return $result | Add-Member -NotePropertyMembers @{ ReportPath = $report; ResultPath = $junit } -PassThru
}

$pwsh = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$nativeCall = "& '$pwsh' -NoProfile -Command 'exit 0'"

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two source folders, each with a function, and a passing test file
# that dot-sources and calls both
$sandbox = New-TestRunnerSandbox
$sourceA = Join-Path $sandbox 'srcA'
$sourceB = Join-Path $sandbox 'srcB'
New-Item -ItemType Directory -Path $sourceA, $sourceB | Out-Null
$alphaPath = Join-Path $sourceA 'Alpha.ps1'
$betaPath = Join-Path $sourceB 'Beta.ps1'
Set-Content -LiteralPath $alphaPath -Value 'function Get-Alpha { return 1 }'
Set-Content -LiteralPath $betaPath -Value 'function Get-Beta { return 2 }'
$passing = @"
. '$alphaPath'
. '$betaPath'
`$null = Get-Alpha
`$null = Get-Beta
Write-Host '2 passed, 0 failed'
exit 0
"@

# Act
$pass = Invoke-WrappedFile -Sandbox $sandbox -Name 'Passing' -Content $passing -SourceRoot @($sourceA, $sourceB)
$coverage = Get-Content -LiteralPath $pass.ReportPath -Raw

# Assert
Assert-Equal -Expected 0 -Actual $pass.ExitCode -Message 'A file that exits 0 makes the wrapper exit 0'
Assert-Equal -Expected 2 -Actual $pass.Passed -Message 'and its own tally line comes through untouched'
Assert-Equal -Expected $false -Actual $pass.Crashed -Message 'A passing file is not a crash'
Assert-That -Condition ($coverage -like '*Alpha.ps1*') -Message 'The coverage report covers the first source folder'
Assert-That -Condition ($coverage -like '*Beta.ps1*') -Message 'and the second, which crossed as one delimited value'
Assert-That -Condition ($coverage -notlike '*Passing.Tests.ps1*') -Message 'but not the test file itself'
Assert-That -Condition ((Get-Content -LiteralPath $pass.ResultPath -Raw) -like '*<testsuite*') `
    -Message 'A JUnit result is written'

#───────────────────────────────────────────────────────────────────────────────
# Act - a file that reports a failure and exits with it
$fail = Invoke-WrappedFile -Sandbox $sandbox -Name 'Failing' -SourceRoot @($sourceA) -Content @"
Write-Host 'the failing detail'
Write-Host '1 passed, 1 failed'
exit 1
"@

# Assert
Assert-Equal -Expected 1 -Actual $fail.ExitCode -Message 'A file that exits 1 makes the wrapper exit 1'
Assert-Equal -Expected 1 -Actual $fail.Failed -Message 'and the failed count comes through'
Assert-Equal -Expected $false -Actual $fail.Crashed -Message 'A failure the file reported is not a crash'
Assert-That -Condition (($fail.Output -join "`n") -like '*the failing detail*') -Message 'What the file printed is kept'
Assert-That -Condition ((Get-Content -LiteralPath $fail.ResultPath -Raw) -like '*<failure*') `
    -Message 'The JUnit result records the file as failed'

#───────────────────────────────────────────────────────────────────────────────
# Act - a file that prints a tally and has no exit statement at all
$noExit = Invoke-WrappedFile -Sandbox $sandbox -Name 'NoExit' -SourceRoot @($sourceA) `
    -Content "Write-Host '2 passed, 0 failed'"
$noExitText = $noExit.Output -join "`n"

# Assert
Assert-Equal -Expected $true -Actual $noExit.Crashed -Message 'A file that never calls exit is a crash, not a pass'
Assert-That -Condition ($noExitText -like '*never calls exit*Complete-TestRun*') `
    -Message 'and the output says what to do about it'
Assert-That -Condition ($noExitText -notlike '*2 passed*') -Message 'without running the file at all'
Assert-That -Condition ($noExitText -notlike '*Pester.psm1*') -Message 'and without Pester''s own stack frames'

#───────────────────────────────────────────────────────────────────────────────
# Act - a file whose unclosed hashtable swallows the rest of it, its exit
# included
$unparsed = Invoke-WrappedFile -Sandbox $sandbox -Name 'Unparsed' -SourceRoot @($sourceA) `
    -Content "Write-Host '1 passed, 0 failed'`n`$x = @{ a = 1`nexit 0"
$unparsedText = $unparsed.Output -join "`n"

# Assert
Assert-Equal -Expected $true -Actual $unparsed.Crashed -Message 'A file that does not parse is a crash'
Assert-That -Condition ($unparsedText -like "*Unparsed.Tests.ps1:2:8: Missing closing '}'*") `
    -Message 'and the output gives the parser''s own error, with its line and column'
Assert-That -Condition ($unparsedText -notlike '*never calls exit*') -Message 'not that the file never calls exit'
Assert-That -Condition ($unparsedText -notlike '*1 passed*') -Message 'without running the file'

#───────────────────────────────────────────────────────────────────────────────
# Act - a file that throws before it can say anything
$throws = Invoke-WrappedFile -Sandbox $sandbox -Name 'Throws' -SourceRoot @($sourceA) `
    -Content "throw 'boom from the test file'`nexit 0"
$throwsText = $throws.Output -join "`n"

# Assert
Assert-Equal -Expected $true -Actual $throws.Crashed -Message 'A file that throws is a crash'
Assert-That -Condition ($throwsText -like '*boom from the test file*') `
    -Message 'and the exception''s message is in the output'
Assert-That -Condition ($throwsText -like '*Throws.Tests.ps1: line 1*') -Message 'with the file''s own stack frame'
Assert-That -Condition ($throwsText -notlike '*Pester.psm1*') -Message 'but none of Pester''s'

#───────────────────────────────────────────────────────────────────────────────
# Act - a file that prints a passing tally, runs a native command, and falls
# off its end
$native = Invoke-WrappedFile -Sandbox $sandbox -Name 'NativeNoExit' -SourceRoot @($sourceA) -Content @"
Write-Host '2 passed, 0 failed'
$nativeCall
"@

# Assert
Assert-Equal -Expected $true -Actual $native.Crashed `
    -Message 'A file ending on a native command without exit is a crash, not exit 0'
Assert-Equal -Expected 1 -Actual $native.ExitCode -Message 'and the wrapper exits 1 for it'

#───────────────────────────────────────────────────────────────────────────────
# Act - a TestKit file whose assertions never ran, and which never exits
$zero = Invoke-WrappedFile -Sandbox $sandbox -Name 'ZeroNoExit' -SourceRoot @($sourceA) `
    -Content (Get-TestKitFileContent -Body 'Complete-TestRun' -NoExit)

# Assert
Assert-Equal -Expected $true -Actual $zero.Crashed -Message 'A zero-assertion file without exit is a crash'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same, with an exit it never reaches, falling off its end after a
# native command
$untaken = Invoke-WrappedFile -Sandbox $sandbox -Name 'UntakenExit' -SourceRoot @($sourceA) `
    -Content (Get-TestKitFileContent -Body "if (`$false) { exit 1 }`nComplete-TestRun`n$nativeCall" -NoExit)

# Assert
Assert-Equal -Expected 0 -Actual $untaken.ExitCode `
    -Message 'A file that falls off its end after a native command looks like exit 0'
Assert-Equal -Expected $true -Actual $untaken.Crashed -Message 'but its tally of no cases at all makes it a crash'

#───────────────────────────────────────────────────────────────────────────────
# Act - an ordinary TestKit file
$normal = Invoke-WrappedFile -Sandbox $sandbox -Name 'Normal' -SourceRoot @($sourceA) `
    -Content (Get-TestKitFileContent -Body "Assert-Equal -Expected 1 -Actual 1 -Message 'one is one'")

# Assert
Assert-Equal -Expected 1 -Actual $normal.Passed -Message 'An ordinary TestKit file reports its case'
Assert-Equal -Expected $false -Actual $normal.Crashed -Message 'and is not a crash'
Assert-Equal -Expected 0 -Actual $normal.ExitCode -Message 'and exits 0'

#───────────────────────────────────────────────────────────────────────────────
# Act - a TestKit file that skips itself
$skip = Invoke-WrappedFile -Sandbox $sandbox -Name 'Skip' -SourceRoot @($sourceA) `
    -Content (Get-TestKitFileContent -Body "exit (Skip-TestRun -Reason 'not on this machine')")

# Assert
Assert-Equal -Expected $true -Actual $skip.Skipped -Message 'A file that skips itself is skipped'
Assert-Equal -Expected 'not on this machine' -Actual $skip.SkipReason -Message 'with the reason it gave'
Assert-Equal -Expected $false -Actual $skip.Crashed -Message 'and is not a crash'

#───────────────────────────────────────────────────────────────────────────────
# Act - a TestKit file whose checks run by other means
$allowed = Invoke-WrappedFile -Sandbox $sandbox -Name 'AllowEmpty' -SourceRoot @($sourceA) `
    -Content (Get-TestKitFileContent -Body 'exit (Complete-TestRun -AllowEmpty)' -NoExit)

# Assert
Assert-Equal -Expected $true -Actual $allowed.AllowedEmpty `
    -Message 'A file ended with Complete-TestRun -AllowEmpty is allowed to run no cases'
Assert-Equal -Expected $false -Actual $allowed.Crashed -Message 'and is not a crash'
Assert-Equal -Expected $false -Actual $allowed.Skipped -Message 'nor a skip'

#───────────────────────────────────────────────────────────────────────────────
# Act - a file that passes run on its own: it reads an unset variable, hits a
# non-terminating error, and writes its tally to the pipeline
$standalone = Invoke-WrappedFile -Sandbox $sandbox -Name 'Standalone' -SourceRoot @($sourceA) -Content @'
$notSetAnywhere
Get-Item -LiteralPath (Join-Path $PSScriptRoot 'no-such-file')
"EAP inside the file: $ErrorActionPreference"
Write-Output '2 passed, 0 failed'
exit 0
'@
$standaloneText = $standalone.Output -join "`n"

# Assert
Assert-Equal -Expected $false -Actual $standalone.Crashed `
    -Message 'The wrapper''s strict mode and error preference do not reach the file'
Assert-Equal -Expected 2 -Actual $standalone.Passed -Message 'A tally written to the pipeline is read'
Assert-That -Condition ($standaloneText -like '*EAP inside the file: Continue*') `
    -Message 'The file runs with $ErrorActionPreference at Continue'
Assert-That -Condition ($standaloneText -like '*Get-Item: *no-such-file*') `
    -Message 'and its non-terminating error is printed, named for its command'

#───────────────────────────────────────────────────────────────────────────────
# Act - a file that leaves its own preference alone and calls a function of a
# module it imports
$preference = Invoke-WrappedFile -Sandbox $sandbox -Name 'Preference' -SourceRoot @($sourceA) -Content @'
New-Module -Name PreferenceProbe -ScriptBlock {
    function Get-ProbePreference { return $ErrorActionPreference }
} | Import-Module
Write-Host "module EAP=[$(Get-ProbePreference)]"
Write-Host "file EAP=[$ErrorActionPreference]"
Write-Host '1 passed, 0 failed'
exit 0
'@

# Assert
Assert-That -Condition ($preference.Output -contains 'module EAP=[Stop]') `
    -Message 'A function of a module the file imports runs with $ErrorActionPreference at Stop, the wrapper''s own'
Assert-That -Condition ($preference.Output -contains 'file EAP=[Continue]') `
    -Message 'while the file itself keeps Continue'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a passing file whose result report goes under a folder with
# brackets in its name, which Pester would read as a wildcard
$bracketFile = Join-Path $sandbox 'Bracket.Tests.ps1'
Set-Content -LiteralPath $bracketFile -Value "Write-Host '1 passed, 0 failed'`nexit 0"
$bracketResult = Join-Path $sandbox 'results [1]' 'Bracket.junit.xml'

# Act
$bracket = Invoke-TestFileProcess -File $bracketFile -Name 'Bracket' -SourceRoot @($sourceA) -Coverage `
    -ReportPath (Join-Path $sandbox 'Bracket.cobertura.xml') -ResultPath $bracketResult
$bracketReport = [string](Get-Content -LiteralPath $bracketResult -Raw -ErrorAction Ignore)

# Assert
Assert-Equal -Expected $false -Actual $bracket.Crashed `
    -Message 'A result path with brackets in it does not make a passing file a crash'
Assert-Equal -Expected 1 -Actual $bracket.Passed -Message 'and its tally comes through'
Assert-That -Condition ($bracketReport -like '*<testsuite*') `
    -Message 'and the JUnit result is written at exactly that path'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a source folder with brackets in its name, which Pester would read
# as a wildcard in a coverage path, beside another source folder, so the folder
# the file runs in, which holds both, has no brackets in it
$sourceBracket = Join-Path $sandbox 'src [b]'
New-Item -ItemType Directory -Path $sourceBracket | Out-Null
$gammaPath = Join-Path $sourceBracket 'Gamma.ps1'
Set-Content -LiteralPath $gammaPath -Value 'function Get-Gamma { return 3 }'

# Act
$bracketSource = Invoke-WrappedFile -Sandbox $sandbox -Name 'BracketSource' `
    -SourceRoot @($sourceA, $sourceBracket) `
    -Content @"
. '$gammaPath'
Get-Gamma | Out-Null
Write-Host '1 passed, 0 failed'
exit 0
"@
$bracketCoverage = [string](Get-Content -LiteralPath $bracketSource.ReportPath -Raw -ErrorAction Ignore)

# Assert
Assert-Equal -Expected $false -Actual $bracketSource.Crashed `
    -Message 'A source folder with brackets in its name does not make a passing file a crash'
Assert-Equal -Expected 1 -Actual $bracketSource.Passed -Message 'and its tally comes through'
Assert-That -Condition ($bracketCoverage -like '*Gamma.ps1*') -Message 'and the coverage report covers that folder'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a passing file whose result report cannot be written: a folder
# already has its path. The child's temporary folder is one of the sandbox's
# own, so what the wrapper leaves behind there can be seen.
$lockedFile = Join-Path $sandbox 'Locked.Tests.ps1'
Set-Content -LiteralPath $lockedFile -Value "Write-Host '1 passed, 0 failed'`nexit 0"
$lockedResult = Join-Path $sandbox 'Locked.junit.xml'
$null = New-Item -ItemType Directory -Path $lockedResult
$childTemp = New-Item -ItemType Directory -Path (Join-Path $sandbox 'child-temp')
$savedTemp = @{}
foreach ($variable in 'TMP', 'TEMP', 'TMPDIR') {
    $savedTemp[$variable] = [Environment]::GetEnvironmentVariable($variable)
}

# Act
try {
    foreach ($variable in $savedTemp.PSBase.Keys) {
        [Environment]::SetEnvironmentVariable($variable, $childTemp.FullName)
    }

    $locked = Invoke-TestFileProcess -File $lockedFile -Name 'Locked' -SourceRoot @($sourceA) -Coverage `
        -ReportPath (Join-Path $sandbox 'Locked.cobertura.xml') -ResultPath $lockedResult
}
finally {
    foreach ($variable in $savedTemp.PSBase.Keys) {
        [Environment]::SetEnvironmentVariable($variable, $savedTemp[$variable])
    }
}

$leftInTemp = @(Get-ChildItem -LiteralPath $childTemp.FullName -Filter 'testrunner-*' -Force)
$lockedLines = @($locked.Output | Where-Object {
    $_.StartsWith("Could not write the JUnit result to '$lockedResult': ") -and
    $_.EndsWith('. An older report may still be at that path.') -and
    -not $_.Contains('..')
})

# Assert
Assert-Equal -Expected $false -Actual $locked.Crashed `
    -Message 'A result report that cannot be written does not make a passing file a crash'
Assert-Equal -Expected 0 -Actual $locked.ExitCode -Message 'and the wrapper exits with the file''s own code'
Assert-Equal -Expected 1 -Actual $lockedLines.Count `
    -Message 'The output says the report could not be written, naming the path, and that an older one may be there'
Assert-Equal -Expected 0 -Actual $leftInTemp.Count -Message 'and the temporary report is not left behind'

#───────────────────────────────────────────────────────────────────────────────
# Act - a file that looks for the drives Pester makes for a test: a temp folder
# (TestDrive:) and a key under HKCU:\Software\Pester (TestRegistry:), which
# exist only while a test runs, so only the file itself can see them
$drives = Invoke-WrappedFile -Sandbox $sandbox -Name 'Drives' -SourceRoot @($sourceA) -Content @'
foreach ($name in 'TestDrive', 'TestRegistry') {
    Write-Host "drive $name=[$([bool](Get-PSDrive -Name $name -ErrorAction Ignore))]"
}
Write-Host '1 passed, 0 failed'
exit 0
'@

# Assert
Assert-Equal -Expected $false -Actual $drives.Crashed -Message 'A file that looks for Pester''s drives runs'
Assert-Equal -Expected @('drive TestDrive=[False]', 'drive TestRegistry=[False]') `
    -Actual @($drives.Output | Where-Object { $_ -like 'drive *' }) `
    -Message 'The wrapper makes no temp folder and no registry key for the file'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that writes to stdout and stderr in turn
$interleaved = @'
Write-Host 'step 1'
Write-Error 'step 2'
Write-Host 'step 3'
Write-Host '0 passed, 1 failed'
exit 1
'@
$expectedOrder = @('step 1', 'Write-Error: step 2', 'step 3', '0 passed, 1 failed')

# Act
$untimed = Invoke-WrappedFile -Sandbox $sandbox -Name 'Order' -SourceRoot @($sourceA) -Content $interleaved
$timed = Invoke-WrappedFile -Sandbox $sandbox -Name 'OrderTimed' -SourceRoot @($sourceA) -Content $interleaved `
    -TimeoutSeconds 300
$untimedOrder = @($untimed.Output | Where-Object { $_ -match 'step|passed' })
$timedOrder = @($timed.Output | Where-Object { $_ -match 'step|passed' })

# Assert
Assert-Equal -Expected $expectedOrder -Actual $untimedOrder -Message 'Errors stay in order with the rest of the output'
Assert-Equal -Expected $expectedOrder -Actual $timedOrder -Message 'with -TimeoutSeconds too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a source folder outside any repository, and the caller inside a
# deeper, unrelated one whose path is longer than the source file's
$plainSource = Join-Path $sandbox 'src'
New-Item -ItemType Directory -Path $plainSource | Out-Null
Set-Content -LiteralPath (Join-Path $plainSource 'A.ps1') -Value 'function Get-A { return 1 }'
$otherRepository = Join-Path $sandbox 'an-unrelated-repository-with-a-long-name'
New-Item -ItemType Directory -Path (Join-Path $otherRepository '.git') | Out-Null
$deepInside = New-Item -ItemType Directory -Path (Join-Path $otherRepository 'a' 'b')
$covering = ". '$(Join-Path $plainSource 'A.ps1')'`n`$null = Get-A`nWrite-Host '1 passed, 0 failed'`nexit 0"

# Act
Push-Location -LiteralPath $deepInside.FullName
try {
    $located = Invoke-WrappedFile -Sandbox $sandbox -Name 'Located' -SourceRoot @($plainSource) -Content $covering
}
finally {
    Pop-Location
}

$locatedReport = [xml](Get-Content -LiteralPath $located.ReportPath -Raw)
$fileNames = @($locatedReport.SelectNodes('//class') | ForEach-Object filename)

# Assert
Assert-Equal -Expected $false -Actual $located.Crashed `
    -Message 'The caller''s own location does not break the coverage report'
Assert-Equal -Expected @('A.ps1') -Actual $fileNames -Message 'and the report''s paths do not depend on it'

#───────────────────────────────────────────────────────────────────────────────
# Act - a coverage folder that does not exist, so Pester gives up on the run
$missingSource = Join-Path $sandbox 'no-such-src'
$unfinished = Invoke-WrappedFile -Sandbox $sandbox -Name 'Unfinished' -SourceRoot @($missingSource) `
    -Content "Write-Host '1 passed, 0 failed'`nexit 0"
$unfinishedText = $unfinished.Output -join "`n"

# Assert
Assert-Equal -Expected $true -Actual $unfinished.Crashed -Message 'A run Pester could not finish is a crash'
Assert-That -Condition ($unfinished.Output[-1] -like 'Pester did not finish the run*') `
    -Message 'and the last line says Pester did not finish'
Assert-That -Condition ($unfinishedText -like '*no-such-src*') -Message 'next to Pester''s own error naming the folder'
Assert-That -Condition ($unfinishedText -notlike '*cannot be found on this object*') `
    -Message 'rather than a strict-mode error from the wrapper'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - Pester modules made for the test, one new enough and one too old
$newPester = New-FakePester -Directory (Join-Path $sandbox 'new') -Version '5.4.0'
$oldPester = New-FakePester -Directory (Join-Path $sandbox 'old') -Version '5.0.0'

# Act
$byPath = Invoke-WrappedFile -Sandbox $sandbox -Name 'ByPath' -SourceRoot @($sourceA) -Content 'exit 0' `
    -PesterPath $newPester
$tooOld = Invoke-WrappedFile -Sandbox $sandbox -Name 'TooOld' -SourceRoot @($sourceA) -Content 'exit 0' `
    -PesterPath $oldPester
$noModule = Invoke-WrappedFile -Sandbox $sandbox -Name 'NoModule' -SourceRoot @($sourceA) -Content 'exit 0' `
    -PesterPath (Join-Path $sandbox 'nowhere' 'Pester.psd1')
$tooOldText = $tooOld.Output -join "`n"

# Assert
Assert-That -Condition ($byPath.Output -contains 'fake Pester 5.4.0 loaded') `
    -Message 'The wrapper imports the Pester it is handed, by its path'
Assert-That -Condition ($tooOldText -like '*Pester 5.0.0*older than 5.3.0*') `
    -Message 'and refuses one older than 5.3.0, naming both versions'
Assert-That -Condition ($tooOldText -notlike '*fake Pester*') -Message 'before loading it'
Assert-That -Condition (($noModule.Output -join "`n") -like '*TESTRUNNER_PESTER_PATH names no file*') `
    -Message 'A path that names no file says so'
Assert-Equal -Expected $true -Actual $tooOld.Crashed -Message 'and the file counts as crashed'

# Cleanup
Remove-TestRunnerSandbox -Path $sandbox

exit (Complete-TestRun)
