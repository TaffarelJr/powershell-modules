#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act
$messages = @(Get-HostMessage { Write-Field -Name 'Branch' -Value 'main' })

# Assert
Assert-Equal -Expected 1 -Actual $messages.Count -Message 'Write-Field prints exactly one line'
Assert-Equal -Expected ('  ' + 'Branch:'.PadRight(14) + ' main') -Actual $messages[0].Message `
    -Message 'The value starts after the name, padded to the default 15-column budget'
Assert-Equal -Expected 'Gray' -Actual $messages[0].Color -Message 'The line is gray'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a name longer than the alignment budget
# still leaves a space before the value instead of crowding it
$long = @(Get-HostMessage { Write-Field -Name 'AVeryLongFieldName' -Value 'x' })

# Assert
Assert-Equal -Expected '  AVeryLongFieldName: x' -Actual $long[0].Message `
    -Message 'An overlong name still gets a separating space before its value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an empty name prints the value alone, as a continuation
$continuation = @(Get-HostMessage { Write-Field -Name '' -Value 'more detail' })

# Assert
Assert-Equal -Expected ('  ' + (' ' * 15) + 'more detail') -Actual $continuation[0].Message `
    -Message 'An empty name leaves the name column blank - no stray colon - so the value lines up with the field above'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - Name/Value objects, as Get-ChildItem Env: produces
$objects = @(
    [PSCustomObject]@{ Name = 'One'; Value = '1' }
    [PSCustomObject]@{ Name = 'Two'; Value = '2' }
)

# Act - piped straight through, binding by property name
$piped = @(Get-HostMessage { $objects | Write-Field })

# Assert
Assert-Equal -Expected @(('  ' + 'One:'.PadRight(14) + ' 1'), ('  ' + 'Two:'.PadRight(14) + ' 2')) `
    -Actual @($piped.Message) `
    -Message 'Each piped object renders its own name and value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Budget sets the alignment column width
$narrow = @(Get-HostMessage { Write-Field -Name 'x' -Value 'y' -Budget 5 })
$tight = @(Get-HostMessage { Write-Field -Name 'x' -Value 'y' -Budget 1 })

# Assert
Assert-Equal -Expected '  x:   y' -Actual $narrow[0].Message `
    -Message 'The value starts exactly -Budget columns after the indent'
Assert-Equal -Expected '  x: y' -Actual $tight[0].Message `
    -Message 'A budget no wider than the name still leaves one space'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an omitted -Value is empty, not an error
$noValue = @(Get-HostMessage { Write-Field -Name 'k' })

# Assert
Assert-Equal -Expected 1 -Actual $noValue.Count -Message 'A field with no value still prints its name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a value with several lines keeps them lined up
$multi = @(Get-HostMessage { Write-Field -Name 'k' -Value "first`nsecond" })

# Assert
Assert-Equal -Expected @(('  ' + 'k:'.PadRight(14) + ' first'), ('  ' + (' ' * 15) + 'second')) `
    -Actual @($multi.Message) `
    -Message 'Later lines of a value line up under the first line''s value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
$expected = @(('  ' + 'Paths:'.PadRight(14) + ' a'), ('  ' + (' ' * 15) + 'b'))

# Act - an array value, given directly and piped as a property
$direct = @(Get-HostMessage { Write-Field -Name 'Paths' -Value @('a', 'b') })
$piped = @(Get-HostMessage { [PSCustomObject]@{ Name = 'Paths'; Value = @('a', 'b') } | Write-Field })

# Assert
Assert-Equal -Expected $expected -Actual @($direct.Message) `
    -Message 'Each item of an array value is its own line, lined up under the first'
Assert-Equal -Expected $expected -Actual @($piped.Message) -Message 'and so is an array bound by property name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
$expected = @(('  ' + 'Env:'.PadRight(14) + ' C = 3'), ('  ' + (' ' * 15) + 'a = 1'), ('  ' + (' ' * 15) + 'b = 2'))

# Act - a dictionary value, as a hashtable, as an ordered one, and bound by property name
$hashtable = @(Get-HostMessage { Write-Field -Name 'Env' -Value @{ b = 2; a = 1; C = 3 } })
$ordered = @(Get-HostMessage { Write-Field -Name 'Env' -Value ([ordered]@{ b = 2; a = 1; C = 3 }) })
$piped = @(Get-HostMessage { [PSCustomObject]@{ Name = 'Env'; Value = @{ b = 2; a = 1; C = 3 } } | Write-Field })

# Assert
Assert-Equal -Expected $expected -Actual @($hashtable.Message) `
    -Message 'A hashtable prints as key = value lines, sorted by key, each under the first'
Assert-Equal -Expected $expected -Actual @($ordered.Message) -Message 'and so does an ordered dictionary'
Assert-Equal -Expected $expected -Actual @($piped.Message) -Message 'and one bound by property name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a dictionary whose keys are named like members of the dictionary itself, and an empty one
$members = @(Get-HostMessage { Write-Field -Name 'Env' -Value @{ Keys = 'k'; Count = 3; Values = 'v' } })
$empty = @(Get-HostMessage { Write-Field -Name 'Env' -Value @{} })

# Assert
Assert-Equal -Expected @(('  ' + 'Env:'.PadRight(14) + ' Count = 3'), ('  ' + (' ' * 15) + 'Keys = k'),
    ('  ' + (' ' * 15) + 'Values = v')) -Actual @($members.Message) `
    -Message 'Every key is printed, whatever it is named'
Assert-Equal -Expected @('  ' + 'Env:'.PadRight(14) + ' ') -Actual @($empty.Message) `
    -Message 'An empty dictionary prints the name alone'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a value that is not text
$number = @(Get-HostMessage { Write-Field -Name 'Count' -Value 7 })
$nothing = @(Get-HostMessage { Write-Field -Name 'Count' -Value $null })

# Assert
Assert-Equal -Expected @('  ' + 'Count:'.PadRight(14) + ' 7') -Actual @($number.Message) `
    -Message 'A number is printed as its text'
Assert-Equal -Expected @('  ' + 'Count:'.PadRight(14) + ' ') -Actual @($nothing.Message) `
    -Message 'and a $null value as nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - an open "Doing" line is closed before the field
$interrupted = @(Get-HostMessage { Write-Doing 'x'; Write-Field -Name 'k' -Value 'v' })

# Assert
Assert-Equal -Expected @('  ▶ x ...', '', ('  ' + 'k:'.PadRight(14) + ' v')) -Actual @($interrupted.Message) `
    -Message 'The open line ends first, so the field starts its own line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$overridden =@(Invoke-Indented -Width 7 { Get-HostMessage { Write-Field -Name 'x' -Value 'y' -Indent 4 } })
$ambient = @(Invoke-Indented -Width 3 { Get-HostMessage { Write-Field -Name 'x' -Value 'y' } })

# Assert
Assert-Equal -Expected ('      ' + 'x:'.PadRight(14) + ' y') -Actual $overridden[0].Message `
    -Message '-Indent 4 replaces the ambient indent: the base two spaces plus four'
Assert-Equal -Expected ('     ' + 'x:'.PadRight(14) + ' y') -Actual $ambient[0].Message `
    -Message 'The ambient indent applies automatically, on top of the base indent'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - values that would otherwise fail inside the writer
Assert-Throws -ScriptBlock { Write-Field -Name 'x' -Value 'y' -Budget 0 } -MessageLike '*Budget*' `
    -Message 'A budget of zero is refused up front, not as an error from inside the padding'
Assert-Throws -ScriptBlock { Write-Field -Name 'x' -Value 'y' -Indent -1 } -MessageLike '*Indent*' `
    -Message 'A negative -Indent is refused'

exit (Complete-TestRun)
