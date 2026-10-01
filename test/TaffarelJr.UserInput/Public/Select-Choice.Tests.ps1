#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')
$module = Get-Module TaffarelJr.UserInput

$options = 'Public', 'Private', 'Internal'
$rejection = 'The answer must be a number from 1 to 3, or one of: Public, Private, Internal'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '2'

# Act
$result = Select-Choice -Prompt 'Visibility' -Option $options

# Assert
Assert-Equal -Expected 'Private' -Actual $result -Message 'A number picks the option at that place in the list'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer 'internal', 'PUBLIC', ' 3 '

# Act
$byText = Select-Choice -Prompt 'Visibility' -Option $options
$upper = Select-Choice -Prompt 'Visibility' -Option $options
$padded = Select-Choice -Prompt 'Visibility' -Option $options

# Assert
Assert-Equal -Expected 'Internal' -Actual $byText `
    -Message 'The option''s own text picks it, in any casing, and comes back as the list spells it'
Assert-Equal -Expected 'Public' -Actual $upper -Message 'whatever case it is typed in'
Assert-Equal -Expected 'Internal' -Actual $padded -Message 'and spaces around a number are ignored'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '1'

# Act
$lines = @(Get-HostOutput { $null = Select-Choice -Prompt 'Visibility' -Option $options })

# Assert
Assert-Equal -Expected @('     1. Public', '     2. Private', '     3. Internal') -Actual $lines `
    -Message 'The options are printed as a numbered list first'
Assert-Equal -Expected @('Visibility') -Actual @(Get-FakePrompt) `
    -Message 'and the question is asked with nothing after it when there is no default'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '', ''

# Act
$fromEnter = Select-Choice -Prompt 'Visibility' -Option $options -Default 'Private'
$lowerDefault = Select-Choice -Prompt 'Visibility' -Option $options -Default 'internal'

# Assert
Assert-Equal -Expected 'Private' -Actual $fromEnter -Message 'A bare Enter takes the default'
Assert-Equal -Expected @('Visibility [2]', 'Visibility [3]') -Actual @(Get-FakePrompt) `
    -Message 'and the prompt shows the default by its number'
Assert-Equal -Expected 'Internal' -Actual $lowerDefault `
    -Message 'A default matches an option whatever its casing, instead of silently being no default'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - answers that are not on the menu, then one that is
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '0', '4', '-1', '1.5', 'nope', ''
Add-FakeAnswer '3'

# Act
$lines = @(Get-HostOutput { $script:retried = Select-Choice -Prompt 'Visibility' -Option $options })
$rejections = @($lines | Where-Object { $_ -like "*$rejection" })

# Assert
Assert-Equal -Expected 'Internal' -Actual $script:retried `
    -Message 'Bad answers are explained and asked again until a good one comes'
Assert-Equal -Expected 6 -Actual $rejections.Count `
    -Message 'Each bad answer - out of range, negative, a fraction, no match, and blank - is explained'
Assert-Equal -Expected 7 -Actual @(Get-FakePrompt).Count -Message 'and the question is asked once more each time'
Assert-Equal -Expected 21 -Actual @($lines | Where-Object { $_ -match '^ {5}\d\. ' }).Count `
    -Message 'with the menu shown again each time, so a person can see what to pick'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nobody to ask again
Install-FakeReadHost
Use-FakeHost -Module $module -UserInteractive $false
Add-FakeAnswer 'nope', '1'

# Act / Assert
Assert-Throws -ScriptBlock { $null = Select-Choice -Prompt 'Visibility' -Option $options } -MessageLike $rejection `
    -Message 'With no one to re-ask, a bad answer fails at once with the reason'
Assert-Equal -Expected 1 -Actual @(Get-FakePrompt).Count -Message 'after being asked only once'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module

# Act
$thrown = Get-ThrownError { Select-Choice -Prompt 'Visibility' -Option $options -Default 'nope' }

# Assert
Assert-Equal -Expected "-Default 'nope' is not one of the options: Public, Private, Internal" `
    -Actual $thrown.Exception.Message `
    -Message 'A default that is not an option is refused, naming it and the options'
Assert-Equal -Expected 'InvalidArgument' -Actual "$($thrown.CategoryInfo.Category)" `
    -Message 'as a mistake in the call, which Invoke-InputRetry would not retry'
Assert-Equal -Expected 0 -Actual @(Get-FakePrompt).Count -Message 'and nobody is asked anything first'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - options that typing could not reach or tell apart
Install-FakeReadHost
Use-FakeHost -Module $module

# Act
$padded = Get-ThrownError { Select-Choice -Prompt 'Visibility' -Option ' Public ', 'Private' }
$duplicated = Get-ThrownError { Select-Choice -Prompt 'Pick' -Option 'a', 'b', 'A' }

# Assert
Assert-Equal -Expected "-Option ' Public ' has spaces around it, so typing it could never match; remove them" `
    -Actual $padded.Exception.Message `
    -Message 'An option with spaces around it is refused, naming it'
Assert-Equal -Expected 'OptionPadded,Select-Choice' -Actual $padded.FullyQualifiedErrorId `
    -Message 'as a mistake in the call, which Invoke-InputRetry would not retry'
Assert-Equal -Expected "-Option lists 'A' more than once, ignoring case, so typing it could not tell them apart" `
    -Actual $duplicated.Exception.Message `
    -Message 'An option listed twice in different casings is refused, naming the second'
Assert-Equal -Expected 'OptionDuplicated,Select-Choice' -Actual $duplicated.FullyQualifiedErrorId `
    -Message 'also as a mistake in the call'
Assert-Equal -Expected 0 -Actual @(Get-FakePrompt).Count -Message 'and nobody is asked anything first'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '1'

# Act
$lines = @(Get-HostOutput { $null = Select-Choice -Prompt 'Pick' -Option 'a', 'b' -Hint @('Pick a branch') })

# Assert
Assert-Equal -Expected @('     Pick a branch', '     1. a', '     2. b') -Actual $lines `
    -Message '-Hint lines are printed before the menu'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an option whose text is a number
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '1', '2'

# Act
$first = Select-Choice -Prompt 'Pick' -Option 'b', '1'
$second = Select-Choice -Prompt 'Pick' -Option 'b', '1'

# Assert
Assert-Equal -Expected 'b' -Actual $first `
    -Message 'A number is reached by its place in the list before it is read as text'
Assert-Equal -Expected '1' -Actual $second -Message 'so the option called 1 is the second one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - more options than a single hotkey could name
Install-FakeReadHost
Use-FakeHost -Module $module
$many = 1..12 | ForEach-Object { "Option$_" }
Add-FakeAnswer '11', 'option12'

# Act
$eleventh = Select-Choice -Prompt 'Pick' -Option $many
$twelfth = Select-Choice -Prompt 'Pick' -Option $many

# Assert
Assert-Equal -Expected 'Option11' -Actual $eleventh -Message 'The eleventh of twelve options is a number away'
Assert-Equal -Expected 'Option12' -Actual $twelfth -Message 'and the twelfth can be typed out'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a single option
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '1'

# Act
$only = Select-Choice -Prompt 'Pick' -Option 'Only'

# Assert
Assert-Equal -Expected 'Only' -Actual $only -Message 'One option is still a menu'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the input ends and there is no default; a second answer is queued to show it is never read
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer -EndOfInput
Add-FakeAnswer '2'

# Act
$ended = Get-ThrownError { $null = Get-HostOutput { Select-Choice -Prompt 'Pick' -Option $options } }

# Assert
Assert-Equal -Expected @('Pick') -Actual @(Get-FakePrompt) `
    -Message 'The end of the input is asked about once, not again'
Assert-Equal -Expected $rejection -Actual $ended.Exception.Message -Message 'and the call fails saying why'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the input ends and there is a default
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer -EndOfInput

# Act
$result = Select-Choice -Prompt 'Pick' -Option $options -Default 'Private'

# Assert
Assert-Equal -Expected 'Private' -Actual $result -Message 'The end of the input takes the default'
Assert-Equal -Expected 1 -Actual @(Get-FakePrompt).Count -Message 'after one question'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare Enter is an answer, not the end of the input
Install-FakeReadHost
Use-FakeHost -Module $module
Add-FakeAnswer '', '2'

# Act
$null = Get-HostOutput { $script:blankThenNumber = Select-Choice -Prompt 'Pick' -Option $options }

# Assert
Assert-Equal -Expected 'Private' -Actual $script:blankThenNumber -Message 'A bare Enter with no default is asked again'
Assert-Equal -Expected 2 -Actual @(Get-FakePrompt).Count -Message 'and the next answer is taken'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the real Read-Host in a real, interactive process whose input is already closed
$closed = Invoke-ChildPowerShell `
    -Script "'RESULT=' + (Select-Choice -Prompt 'Visibility' -Option 'Public', 'Private', 'Internal')"

# Assert
Assert-That -Condition ($closed.ExitCode -ne 0 -and -not $closed.TimedOut) `
    -Message 'With the input closed and no default, it fails instead of waiting or picking one'
Assert-Equal -Expected 1 -Actual ([regex]::Matches($closed.Output, [regex]::Escape('1. Public'))).Count `
    -Message 'after showing the menu once, not again for every attempt'
Assert-Equal -Expected 1 -Actual ([regex]::Matches($closed.Output, [regex]::Escape($rejection))).Count `
    -Message 'and saying why, once'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the real Read-Host, in real processes. An answer piped in
$byNumber = Invoke-ChildPowerShell `
    -Script "'RESULT=' + (Select-Choice -Prompt 'Visibility' -Option 'Public', 'Private', 'Internal')" `
    -StdIn '2'
$byText = Invoke-ChildPowerShell `
    -Script "'RESULT=' + (Select-Choice -Prompt 'Visibility' -Option 'Public', 'Private', 'Internal')" `
    -StdIn 'private'
$retried = Invoke-ChildPowerShell `
    -Script "'RESULT=' + (Select-Choice -Prompt 'Visibility' -Option 'Public', 'Private', 'Internal')" `
    -StdIn 'x', '2'

# Assert
Assert-Equal -Expected 'RESULT=Private' -Actual $byNumber.Output.Trim().Split("`n")[-1] `
    -Message 'A number piped to the real Read-Host picks the option'
Assert-Equal -Expected 'RESULT=Private' -Actual $byText.Output.Trim().Split("`n")[-1] -Message 'and so does its text'
Assert-That -Condition ($retried.Output -like "*$rejection*") -Message 'A bad answer in the real host is explained'
Assert-Equal -Expected 'RESULT=Private' -Actual $retried.Output.Trim().Split("`n")[-1] -Message 'and asked again'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the real Read-Host with the input already closed
$eof = Invoke-ChildPowerShell `
    -Script "'RESULT=' + (Select-Choice -Prompt 'Visibility' -Option 'Public', 'Private', 'Internal')" `
    -Environment @{ CI = 'true' }
$withDefault = Invoke-ChildPowerShell `
    -Script "'RESULT=' + (Select-Choice -Prompt 'Visibility' -Option 'Public', 'Private', 'Internal' -Default 'Private')"

# Assert
Assert-That -Condition ($eof.ExitCode -ne 0 -and -not $eof.TimedOut) `
    -Message 'With nobody to answer and no default, it fails instead of waiting or picking one'
Assert-Equal -Expected 1 -Actual ([regex]::Matches($eof.Output, [regex]::Escape($rejection))).Count `
    -Message 'saying why, once'
Assert-That -Condition ($eof.Output -notlike '*Object reference*') -Message 'and not with a null reference error'
Assert-Equal -Expected 'RESULT=Private' -Actual $withDefault.Output.Trim().Split("`n")[-1] `
    -Message 'With a default, the same closed input takes it'

exit (Complete-TestRun)
