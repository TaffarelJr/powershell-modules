#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
$module = Get-Module TaffarelJr.Tally

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$wrapped = 'noted' | Add-Member -NotePropertyName 'Name' -NotePropertyValue 'other' -PassThru

# Act
$plain = & $module { Resolve-TallyName -InputObject 'passed' }
$fromWrapped = & $module { param($Value) Resolve-TallyName -InputObject $Value } $wrapped

# Assert
Assert-Equal -Expected 'passed' -Actual $plain -Message 'A string is the name itself'
Assert-Equal -Expected 'noted' -Actual $fromWrapped `
    -Message 'and stays the name even when it carries a Name note property of its own'

#───────────────────────────────────────────────────────────────────────────────
# Act
$number = & $module { Resolve-TallyName -InputObject 42 }
$character = & $module { Resolve-TallyName -InputObject ([char]'x') }

# Assert
Assert-Equal -Expected '42' -Actual $number -Message 'A number is named by its text'
Assert-Equal -Expected 'x' -Actual $character -Message 'and so is a character'

#───────────────────────────────────────────────────────────────────────────────
# Act
$decimal = & $module { Resolve-TallyName -InputObject ([decimal]1.5) }
$day = & $module { Resolve-TallyName -InputObject ([DayOfWeek]::Monday) }
$flag = & $module { Resolve-TallyName -InputObject $true }

# Assert
Assert-Equal -Expected '1.5' -Actual $decimal -Message 'A decimal is named by its text'
Assert-Equal -Expected 'Monday' -Actual $day -Message 'and so is an enum value'
Assert-Equal -Expected 'True' -Actual $flag -Message 'and a boolean'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$entry = @(@{ k = 2 }.GetEnumerator())[0]
$pair = [Collections.Generic.KeyValuePair[string, int]]::new('kv', 3)
$when = [DateTime]::new(2026, 1, 2)

# Act
$fromEntry = & $module { param($Value) Resolve-TallyName -InputObject $Value } $entry
$fromPair = { & $module { param($Value) Resolve-TallyName -InputObject $Value } $pair }
$fromDate = { & $module { param($Value) Resolve-TallyName -InputObject $Value } $when }

# Assert
Assert-Equal -Expected 'k' -Actual $fromEntry `
    -Message 'A dictionary entry, a struct with a Name property, is named by its key'
Assert-Throws -ScriptBlock $fromPair `
    -MessageLike '*`[System.Collections.Generic.KeyValuePair`[string,int`]`]: *Name property*' `
    -Message 'A struct with no Name property is refused, not named by its own text, its type named readably'
Assert-Throws -ScriptBlock $fromDate -MessageLike '*DateTime*Name property*' -Message 'and so is a date'

#───────────────────────────────────────────────────────────────────────────────
# Act
$named = & $module { Resolve-TallyName -InputObject ([PSCustomObject]@{ Name = 'seen'; Count = 3 }) }
$numericName = & $module { Resolve-TallyName -InputObject ([PSCustomObject]@{ Name = 7 }) }
$file = & $module { Resolve-TallyName -InputObject ([IO.FileInfo]::new('notes.txt')) }

# Assert
Assert-Equal -Expected 'seen' -Actual $named -Message 'An object is named by its Name property'
Assert-Equal -Expected '7' -Actual $numericName -Message 'which is read as text when it is not a string'
Assert-Equal -Expected 'notes.txt' -Actual $file -Message 'and a .NET object''s own Name property counts too'

#───────────────────────────────────────────────────────────────────────────────
# Act
$noName = { & $module { Resolve-TallyName -InputObject ([PSCustomObject]@{ Extension = '.txt' }) } }
$dictionary = { & $module { Resolve-TallyName -InputObject @{ Name = 'x' } } }

# Assert
Assert-Throws -ScriptBlock $noName -MessageLike '*PSCustomObject*Name property*ForEach-Object*' `
    -Message 'An object with no Name property is refused, naming its type and how to pass the name instead'
Assert-Throws -ScriptBlock $dictionary -MessageLike '*Hashtable*Name property*' `
    -Message 'and a dictionary has no Name property, whatever its keys'

#───────────────────────────────────────────────────────────────────────────────
# Act
$nullName = { & $module { Resolve-TallyName -InputObject $null } }
$nullProperty = { & $module { Resolve-TallyName -InputObject ([PSCustomObject]@{ Name = $null }) } }
$padded = { & $module { Resolve-TallyName -InputObject 'padded ' } }
$lineBreak = { & $module { Resolve-TallyName -InputObject "a$([char]0x2028)b" } }

# Assert
Assert-Throws -ScriptBlock $nullName -MessageLike '*one line*no leading or trailing whitespace*' `
    -Message 'A $null name is refused, with the rule'
Assert-Throws -ScriptBlock $nullProperty -MessageLike '*one line*' -Message 'and so is a Name property holding $null'
Assert-Throws -ScriptBlock $padded -MessageLike "*'padded '*one line*" `
    -Message 'A name with trailing whitespace is refused, quoting it'
Assert-Throws -ScriptBlock $lineBreak -MessageLike '*one line*' -Message 'and so is one holding a Unicode line break'

exit (Complete-TestRun)
