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
Add-FakeAnswer '  typed  '

# Act
$text = & $module { Read-InputText -Prompt 'Name' }

# Assert
Assert-Equal -Expected '  typed  ' -Actual $text -Message 'What was typed comes back as Read-Host gave it, untrimmed'
Assert-Equal -Expected @('Name') -Actual @(Get-FakePrompt) -Message 'after the question alone'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Add-FakeAnswer ''
Add-FakeAnswer -EndOfInput

# Act
$blank = & $module { Read-InputText -Prompt 'Name' -Default 'fallback' }
$ended = & $module { Read-InputText -Prompt 'Name' -Default 'fallback' }

# Assert
Assert-Equal -Expected '' -Actual $blank -Message 'A bare Enter is an empty string, with no default applied'
Assert-That -Condition ($null -eq $ended) -Message 'and the end of the input is $null, which is not the same'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Add-FakeAnswer 'a', 'b', 'c'

# Act
$null = & $module { Read-InputText -Prompt 'Visibility' -Choice 'Public', 'Private' }
$null = & $module { Read-InputText -Prompt 'Visibility' -Default 'Private' }
$null = & $module { Read-InputText -Prompt 'Visibility' -Choice 'Public', 'Private' -Default 'Private' }

# Assert
Assert-Equal -Expected @('Visibility (Public/Private)', 'Visibility [Private]',
        'Visibility (Public/Private) [Private]') `
    -Actual @(Get-FakePrompt) -Message 'The choices and the default are shown after the question, when there are any'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Add-FakeAnswer 'a'

# Act
$lines = @(Get-HostOutput { $null = & $module { Read-InputText -Prompt 'Name' -Hint 'line one', 'line two' } })

# Assert
Assert-Equal -Expected @('     line one', '     line two') -Actual $lines `
    -Message 'Each hint is printed as a detail line first'

exit (Complete-TestRun)
