#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')
$module = Get-Module TaffarelJr.UserInput

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the full word, the short form, in any case, with spaces
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer 'y', 'yes', 'Y', 'YES', ' y '

# Act
$answers = 1..5 | ForEach-Object { Confirm-Input -Prompt 'Proceed?' }

# Assert
Assert-Equal -Expected @($true, $true, $true, $true, $true) -Actual @($answers) `
    -Message 'y and yes answer yes, in any case and with spaces around'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer 'n', 'no', 'N', 'NO'

# Act
$answers = 1..4 | ForEach-Object { Confirm-Input -Prompt 'Proceed?' }

# Assert
Assert-Equal -Expected @($false, $false, $false, $false) -Actual @($answers) -Message 'n and no answer no, in any case'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare Enter
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '', ''

# Act
$yes = Confirm-Input -Prompt 'Proceed?' -Default
$no = Confirm-Input -Prompt 'Proceed?'

# Assert
Assert-Equal -Expected $true -Actual $yes -Message 'A bare Enter accepts -Default when it defaults to yes'
Assert-Equal -Expected $false -Actual $no -Message 'and defaults to no without it'
Assert-Equal -Expected @('Proceed? (y/n) [y]', 'Proceed? (y/n) [n]') -Actual @(Get-FakePrompt) `
    -Message 'The prompt shows the choices and which one a bare Enter picks'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an answer that is neither
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer 'maybe', 'y'

# Act
$lines = @(Get-HostOutput { $script:result = Confirm-Input -Prompt 'Proceed?' })
$warnings = @($lines | Where-Object { $_ -like '*The answer must be one of: y, yes, n, no' })

# Assert
Assert-Equal -Expected $true -Actual $script:result -Message 'The eventual valid answer is returned after a bad one'
Assert-Equal -Expected 1 -Actual $warnings.Count -Message 'The bad answer is explained once, naming what is accepted'
Assert-Equal -Expected 0 -Actual @($lines | Where-Object { $_ -like '*Proceed?*' }).Count `
    -Message 'without repeating the question as if it were a label'
Assert-Equal -Expected 2 -Actual @(Get-FakePrompt).Count -Message 'and the question is asked again'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nobody to ask again
Install-FakeReadHost
Use-FakeHost -Module $module -UserInteractive $false
Add-FakeAnswer 'maybe', 'y'

# Act / Assert
Assert-Throws -ScriptBlock { $null = Confirm-Input -Prompt 'Proceed?' } `
    -MessageLike 'The answer must be one of: y, yes, n, no' `
    -Message 'With no one to re-ask, a bad answer fails at once'
Assert-Equal -Expected 1 -Actual @(Get-FakePrompt).Count -Message 'after being asked once'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer 'y'

# Act
$lines = @(Get-HostOutput { $null = Confirm-Input -Prompt 'Proceed?' -Hint @('This deletes the branch', 'on the remote too') })

# Assert
Assert-Equal -Expected @('     This deletes the branch', '     on the remote too') -Actual $lines `
    -Message '-Hint prints one detail line per entry, before the question'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the real Read-Host in real processes
$script = "[string](Confirm-Input -Prompt 'Proceed?')"
$piped = Invoke-ChildPowerShell -Script $script -StdIn 'yes'
$closed = Invoke-ChildPowerShell -Script $script
$closedYes = Invoke-ChildPowerShell -Script "[string](Confirm-Input -Prompt 'Proceed?' -Default)"
$flagged = Invoke-ChildPowerShell -Script $script -Flag '-NonInteractive'

# Assert
Assert-Equal -Expected 'True' -Actual $piped.Output.Trim().Split("`n")[-1] -Message 'An answer piped in is read'
Assert-Equal -Expected 'False' -Actual $closed.Output.Trim().Split("`n")[-1] `
    -Message 'With the input closed, the answer is the default, no'
Assert-Equal -Expected 'True' -Actual $closedYes.Output.Trim().Split("`n")[-1] -Message 'or yes, with -Default'
Assert-That -Condition ($flagged.ExitCode -ne 0) -Message 'A session started with -NonInteractive fails'
Assert-Equal -Expected 1 -Actual ([regex]::Matches($flagged.Output, 'NonInteractive mode')).Count `
    -Message 'once, with Read-Host''s explanation, instead of being retried nine times'

exit (Complete-TestRun)
