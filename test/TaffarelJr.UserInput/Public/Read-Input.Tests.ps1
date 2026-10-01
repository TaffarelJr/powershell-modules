#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Add-FakeAnswer '  hello  '

# Act
$result = Read-Input -Prompt 'Name'

# Assert
Assert-Equal -Expected 'hello' -Actual $result -Message 'A typed answer is trimmed'
Assert-Equal -Expected @('Name') -Actual @(Get-FakePrompt) `
    -Message 'and asked with just the prompt when there is no choice or default'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Add-FakeAnswer '', '   ', ''

# Act
$blank = Read-Input -Prompt 'Name' -Default 'fallback'
$spaces = Read-Input -Prompt 'Name' -Default 'fallback'
$none = Read-Input -Prompt 'Name'

# Assert
Assert-Equal -Expected 'fallback' -Actual $blank -Message 'A blank answer resolves to -Default'
Assert-Equal -Expected 'fallback' -Actual $spaces -Message 'and so does one of only spaces'
Assert-Equal -Expected '' -Actual $none -Message 'With no -Default, a blank answer is an empty string'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Add-FakeAnswer '', 'typed'

# Act
$padded = Read-Input -Prompt 'Name' -Default '  spaced  '
$typed = Read-Input -Prompt 'Name' -Default 'ignored'

# Assert
Assert-Equal -Expected '  spaced  ' -Actual $padded -Message 'A default is handed back exactly as given, not trimmed'
Assert-Equal -Expected 'typed' -Actual $typed -Message 'and a typed answer wins over it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Add-FakeAnswer 'x', 'y', 'z'

# Act
$null = Read-Input -Prompt 'Visibility' -Choice 'Public', 'Private' -Default 'Public'
$null = Read-Input -Prompt 'Visibility' -Choice 'Public', 'Private'
$null = Read-Input -Prompt 'Visibility' -Default 'Public'

# Assert
Assert-Equal -Expected @('Visibility (Public/Private) [Public]', 'Visibility (Public/Private)', 'Visibility [Public]') `
    -Actual @(Get-FakePrompt) `
    -Message 'The label shows the choices and then the default, each only when given'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Add-FakeAnswer 'Archived'

# Act
$outside = Read-Input -Prompt 'Visibility' -Choice 'Public', 'Private'

# Assert
Assert-Equal -Expected 'Archived' -Actual $outside `
    -Message '-Choice is only shown: an answer outside it is returned as typed, for Assert-Input to judge'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Add-FakeAnswer 'y'

# Act
$lines = @(Get-HostOutput { $null = Read-Input -Prompt 'Name' -Hint @('line one', 'line two') })

# Assert
Assert-Equal -Expected @('     line one', '     line two') -Actual $lines `
    -Message '-Hint prints one detail line per entry, before the prompt'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the real Read-Host, in real processes
$script = "'[' + (Read-Input -Prompt 'Name' -Default 'fallback') + ']'"
$closed = Invoke-ChildPowerShell -Script $script
$piped = Invoke-ChildPowerShell -Script $script -StdIn '  piped  '
$flagged = Invoke-ChildPowerShell -Script $script -Flag '-NonInteractive'

# Assert
Assert-Equal -Expected '[fallback]' -Actual $closed.Output.Trim().Split("`n")[-1] `
    -Message 'With the input closed, the answer is the default'
Assert-Equal -Expected '[piped]' -Actual $piped.Output.Trim().Split("`n")[-1] `
    -Message 'An answer piped in is read and trimmed'
Assert-That -Condition ($flagged.ExitCode -ne 0 -and $flagged.Output -like '*PowerShell is in NonInteractive mode*') `
    -Message 'A session started with -NonInteractive fails with Read-Host''s own explanation'

exit (Complete-TestRun)
