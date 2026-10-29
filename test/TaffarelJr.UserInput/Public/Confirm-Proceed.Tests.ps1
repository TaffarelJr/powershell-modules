#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the word, in any casing, with or without spaces around it
Install-FakeReadHost
Add-FakeAnswer 'yes', 'YES', 'Yes', '  yes  '

# Act
$answers = 1..4 | ForEach-Object { Confirm-Proceed -Action 'delete the branch' }

# Assert
Assert-Equal -Expected @($true, $true, $true, $true) -Actual @($answers) `
    -Message 'The word yes proceeds, whatever its casing and whatever surrounds it'
Assert-Equal -Expected "Type 'yes' to delete the branch" -Actual (Get-FakePrompt)[0] `
    -Message 'The prompt says what is about to happen'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - inside an indented region
Install-FakeReadHost
Add-FakeAnswer 'yes'
Push-Indent -Width 4

# Act
try {
    $null = Confirm-Proceed -Action 'delete the branch'
}
finally {
    Pop-Indent
}

# Assert
Assert-Equal -Expected @("    Type 'yes' to delete the branch") -Actual @(Get-FakePrompt) `
    -Message 'The prompt is indented as far as the current Push-Indent level'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - anything else is a final no
Install-FakeReadHost
Add-FakeAnswer 'y', 'no', 'yes please', 'yess', ''

# Act
$lines = @(Get-HostOutput { $script:answers = 1..5 | ForEach-Object { Confirm-Proceed -Action 'delete the branch' } })

# Assert
Assert-Equal -Expected @($false, $false, $false, $false, $false) -Actual @($script:answers) `
    -Message 'A short y, no, extra words, a typo, and a bare Enter all decline'
Assert-Equal -Expected 5 -Actual @($lines | Where-Object { $_ -like '*Aborted by user' }).Count `
    -Message 'Each says the run was aborted'
Assert-Equal -Expected 5 -Actual @(Get-FakePrompt).Count -Message 'and none is asked again - a wrong answer is final'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the real Read-Host in real processes
$script = "[string](Confirm-Proceed -Action 'delete the branch')"
$piped = Invoke-ChildPowerShell -Script $script -StdIn 'yes'
$closed = Invoke-ChildPowerShell -Script $script
$flagged = Invoke-ChildPowerShell -Script $script -Flag '-NonInteractive'

# Assert
Assert-Equal -Expected 'True' -Actual $piped.Output.Trim().Split("`n")[-1] -Message 'yes piped in proceeds'
Assert-Equal -Expected 'False' -Actual $closed.Output.Trim().Split("`n")[-1] `
    -Message 'With the input closed, the gate stays shut'
Assert-That -Condition ($closed.Output -like '*Aborted by user*') -Message 'and says so'
Assert-That -Condition ($flagged.ExitCode -ne 0 -and $flagged.Output -like '*PowerShell is in NonInteractive mode*') `
    -Message 'A session that cannot be asked at all fails rather than carrying on'

exit (Complete-TestRun)
