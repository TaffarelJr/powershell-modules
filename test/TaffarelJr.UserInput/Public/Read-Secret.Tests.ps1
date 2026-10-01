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
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '  s3cr3t  '

# Act
$result = Read-Secret -Prompt 'Token'

# Assert
Assert-Equal -Expected '  s3cr3t  ' -Actual $result `
    -Message 'A secret is returned exactly as typed, untrimmed, unlike Read-Input'
Assert-Equal -Expected @('Token') -Actual @(Get-FakePrompt) -Message 'and asked with just the prompt'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '', "p`$w'rd`"é"

# Act
$empty = Read-Secret -Prompt 'Token'
$odd = Read-Secret -Prompt 'Token'

# Assert
Assert-Equal -Expected '' -Actual $empty -Message 'An empty entry is an empty string, with no default to fall back on'
Assert-Equal -Expected "p`$w'rd`"é" -Actual $odd -Message 'Dollar signs, quotes, and non-ASCII characters survive'
Assert-That -Condition ($odd -is [string]) -Message 'and what comes back is plain text, ready to hand on'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer 'anything'

# Act
$lines = @(Get-HostOutput { $null = Read-Secret -Prompt 'Token' -Hint @('line one') })

# Assert
Assert-Equal -Expected @('     line one') -Actual $lines -Message '-Hint prints a detail line before the prompt'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - input from a pipe or a file, which Read-Host -AsSecureString cannot read
Install-FakeReadHost
Use-FakeHost -Module $module -InputRedirected

# Act
$piped = Invoke-WithConsoleInput -Text "  p`$w rd  `nsecond line`n" -ScriptBlock { Read-Secret -Prompt 'Token' }
$atEnd = Invoke-WithConsoleInput -Text '' -ScriptBlock { Read-Secret -Prompt 'Token' }

# Assert
Assert-Equal -Expected "  p`$w rd  " -Actual $piped -Message 'Redirected input gives its first line, untrimmed'
Assert-Equal -Expected '' -Actual $atEnd `
    -Message 'and input already at its end gives an empty string, as the other prompts do'
Assert-Equal -Expected 0 -Actual @(Get-FakePrompt).Count `
    -Message 'without asking Read-Host, which would wait on the console instead'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - redirected input in a session started with -NonInteractive
Install-FakeReadHost
Use-FakeHost -Module $module -InputRedirected -CommandLine @('pwsh', '-NonInteractive')
Add-FakeAnswer 'from Read-Host'

# Act
$flaggedRedirected = Invoke-WithConsoleInput -Text "from the pipe`n" -ScriptBlock { Read-Secret -Prompt 'Token' }

# Assert
Assert-Equal -Expected 'from Read-Host' -Actual $flaggedRedirected `
    -Message 'Under -NonInteractive it still goes to Read-Host, whose own error says nobody can be asked'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the real Read-Host in real processes
$script = "'[' + (Read-Secret -Prompt 'Token') + ']'"
$piped = Invoke-ChildPowerShell -Script $script -StdIn '  piped secret  '
$closed = Invoke-ChildPowerShell -Script $script
$onCi = Invoke-ChildPowerShell -Script $script -Environment @{ CI = 'true' }
$flagged = Invoke-ChildPowerShell -Script $script -Flag '-NonInteractive'

# Assert
Assert-Equal -Expected $false -Actual $piped.TimedOut `
    -Message 'A secret piped in does not leave it waiting on the console'
Assert-Equal -Expected '[  piped secret  ]' -Actual $piped.Output.Trim().Split("`n")[-1] `
    -Message 'and is read, untrimmed'
Assert-Equal -Expected $false -Actual $closed.TimedOut -Message 'With the input closed it does not wait either'
Assert-Equal -Expected '[]' -Actual $closed.Output.Trim().Split("`n")[-1] -Message 'and the secret is empty'
Assert-Equal -Expected '[]' -Actual $onCi.Output.Trim().Split("`n")[-1] -Message 'and the same on CI'
Assert-That -Condition ($flagged.ExitCode -ne 0 -and $flagged.Output -like '*PowerShell is in NonInteractive mode*') `
    -Message 'A session started with -NonInteractive fails with Read-Host''s own explanation'

exit (Complete-TestRun)
