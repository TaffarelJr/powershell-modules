#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/New-TestFileResult.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Test-FileFailed.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Format-TestVerdict.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Write-TestResult.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a passing result
$passResult = New-TestFileResult -Name 'x' -Passed 4 -Seconds 1.234 -Output 'line one', 'line two'

# Act
$lines = @(Get-HostOutput { Write-TestResult -Result $passResult })

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'A passing result prints only the verdict line, not its output'
Assert-That -Condition ($lines[0] -like '*4 passed*1.2s*') `
    -Message 'The verdict line names the pass count and the elapsed seconds'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a culture that writes a decimal comma
$culture = [Globalization.CultureInfo]::CurrentCulture
[Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('de-DE')

# Act
try {
    $germanLines = @(Get-HostOutput { Write-TestResult -Result $passResult })
}
finally {
    [Globalization.CultureInfo]::CurrentCulture = $culture
}

# Assert
Assert-That -Condition ($germanLines[0] -like '*4 passed*1.2s*') `
    -Message 'The elapsed seconds read the same whatever the culture'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failing result
$failResult = New-TestFileResult -Name 'x' -Passed 2 -Failed 1 -ExitCode 1 -Seconds 0.5 -Output 'the actual error'

# Act
$failLines = @(Get-HostOutput { Write-TestResult -Result $failResult })

# Assert
Assert-Equal -Expected 2 -Actual $failLines.Count -Message 'A failing result also prints its captured output'
Assert-That -Condition ($failLines[1] -like '*the actual error*') `
    -Message 'The failing output is printed after the verdict'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a crash at exit 0, whose output is the only clue to what went wrong
$crashResult = New-TestFileResult -Name 'x' -Crashed -Output 'something broke before any tally'

# Act
$crashLines = @(Get-HostOutput { Write-TestResult -Result $crashResult })

# Assert
Assert-Equal -Expected 2 -Actual $crashLines.Count -Message 'A crash prints its output even though the exit code was 0'
Assert-That -Condition ($crashLines[1] -like '*something broke before any tally*') `
    -Message 'The crash''s output is what is printed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - failed cases in a file that exited 0
$liarResult = New-TestFileResult -Name 'x' -Passed 3 -Failed 2 -Output 'FAIL - a case'

# Act
$liarLines = @(Get-HostOutput { Write-TestResult -Result $liarResult })

# Assert
Assert-That -Condition ($liarLines[0] -like '*❌*2 failed*') `
    -Message 'A failed case is printed as a failure whatever the exit code says'
Assert-Equal -Expected 2 -Actual $liarLines.Count -Message 'and its output is printed with it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a passing result, but the caller asked to see output anyway
$shownLines = @(Get-HostOutput { Write-TestResult -Result $passResult -ShowOutput })

# Assert
Assert-Equal -Expected 3 -Actual $shownLines.Count -Message '-ShowOutput prints a passing result''s output too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the name leads the line, behind the console module's marker for a pass
$named = New-TestFileResult -Name 'Sub/Thing' -Passed 4 -Seconds 1.234
$namedLines = @(Get-HostOutput { Write-TestResult -Result $named })

# Assert
Assert-That -Condition ($namedLines[0] -like '*✅*Sub/Thing*4 passed*1.2s') `
    -Message 'A passing file is marked as a success, with its name before its verdict'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a file that skipped itself
$skipResult = New-TestFileResult -Name 'Gated' -Skipped -SkipReason 'gh is not installed'
$skipLines = @(Get-HostOutput { Write-TestResult -Result $skipResult })

# Assert
Assert-Equal -Expected 1 -Actual $skipLines.Count `
    -Message 'A skipped file prints one line, since a skip is not a failure'
Assert-That -Condition ($skipLines[0] -like '*⏭*Gated*skipped - gh is not installed*') `
    -Message 'marked as a skip, with its reason'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a failing result whose output has a blank line in it
$blankResult = New-TestFileResult -Name 'x' -Passed 1 -Failed 1 -ExitCode 1 -Output 'first', '', 'last'
$blankLines = @(Get-HostOutput { Write-TestResult -Result $blankResult })

# Assert
Assert-Equal -Expected 3 -Actual $blankLines.Count `
    -Message 'A blank line of output is left out, not printed as a placeholder'
Assert-That -Condition ($blankLines[1] -like '*first*' -and $blankLines[2] -like '*last*') `
    -Message 'and the lines around it are kept in order'

exit (Complete-TestRun)
