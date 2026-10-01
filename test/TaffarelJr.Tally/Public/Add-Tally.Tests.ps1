#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1'
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module $modulePath -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
Add-Tally -Name 'passed'

# Assert
Assert-Equal -Expected 1 -Actual (Get-Tally -Name 'passed') -Message 'A first Add-Tally call with no -Amount adds one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed'

# Act
Add-Tally -Name 'passed'

# Assert
Assert-Equal -Expected 2 -Actual (Get-Tally -Name 'passed') `
    -Message 'A second Add-Tally call on the same name accumulates'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
Add-Tally -Name 'failed' -Amount 3

# Assert
Assert-Equal -Expected 3 -Actual (Get-Tally -Name 'failed') -Message 'Add-Tally -Amount adds that many at once'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'failed' -Amount 3

# Act
Add-Tally -Name 'failed' -Amount -1

# Assert
Assert-Equal -Expected 2 -Actual (Get-Tally -Name 'failed') -Message 'A negative -Amount decrements the tally'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
Add-Tally -Name 'bytes' -Amount 3000000000
Add-Tally -Name 'bytes' -Amount 3000000000
$bytes = Get-Tally -Name 'bytes'

# Assert
Assert-Equal -Expected 6000000000 -Actual $bytes -Message 'Counts are not limited to what fits in an int'
Assert-Equal -Expected 'System.Int64' -Actual $bytes.GetType().FullName -Message 'and a count is a [long]'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'big' -Amount ([long]::MaxValue)

# Act
$overflow = { Add-Tally -Name 'big' }

# Assert
Assert-Throws -ScriptBlock $overflow -MessageLike "*'big'*overflow*" `
    -Message 'Adding past the largest count a [long] holds is refused, naming the counter'
Assert-Equal -Expected ([long]::MaxValue) -Actual (Get-Tally -Name 'big') `
    -Message 'and the count is left as it was'
Assert-Equal -Expected 'System.Int64' -Actual (Get-Tally -Name 'big').GetType().FullName `
    -Message 'still a [long], not widened to a floating-point number'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'low' -Amount ([long]::MinValue)

# Act
$underflow = { Add-Tally -Name 'low' -Amount -1 }

# Assert
Assert-Throws -ScriptBlock $underflow -MessageLike "*'low'*overflow*" `
    -Message 'Subtracting past the smallest count a [long] holds is refused too'
Assert-Equal -Expected ([long]::MinValue) -Actual (Get-Tally -Name 'low') -Message 'and that count is left as it was'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
Add-Tally -Name 'odd' -Amount 1.5
Add-Tally -Name 'even' -Amount 2.5

# Assert
Assert-Equal -Expected 2 -Actual (Get-Tally -Name 'odd') -Message 'A fractional -Amount is rounded to a whole number'
Assert-Equal -Expected 2 -Actual (Get-Tally -Name 'even') -Message 'and a half rounds to the even neighbor'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Clear-Tally -Key 'MyModule'
Add-Tally -Name 'passed' -Amount 2

# Act
Add-Tally -Name 'passed' -Key 'MyModule' -Amount 7

# Assert
Assert-Equal -Expected 7 -Actual (Get-Tally -Name 'passed' -Key 'MyModule') `
    -Message 'Add-Tally -Key tallies under its own namespace'
Assert-Equal -Expected 2 -Actual (Get-Tally -Name 'passed') `
    -Message 'Add-Tally -Key leaves the shared, global counter of the same name untouched'
Clear-Tally -Key 'MyModule'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Clear-Tally -Key 'MyModule'

# Act
Add-Tally -Name 'passed' -Key 'MyModule'
Add-Tally -Name 'passed' -Key 'MYMODULE'

# Assert
Assert-Equal -Expected 2 -Actual (Get-Tally -Name 'passed' -Key 'mymodule') `
    -Message 'Keys are not case-sensitive, so all three spellings are one namespace'
Clear-Tally -Key 'MyModule'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'kept' -Amount 5

# Act
$nullKey = { Add-Tally -Name 'kept' -Key $null }
$emptyKey = { Add-Tally -Name 'kept' -Key '' }
$blankKey = { Add-Tally -Name 'kept' -Key '  ' }

# Assert
Assert-Throws -ScriptBlock $nullKey -MessageLike "*'Key'*non-blank*" `
    -Message 'A $null -Key is refused rather than meaning the global counters'
Assert-Throws -ScriptBlock $emptyKey -MessageLike "*'Key'*non-blank*" -Message 'and so is an empty one'
Assert-Throws -ScriptBlock $blankKey -MessageLike "*'Key'*non-blank*" -Message 'and one of only whitespace'
Assert-Equal -Expected 5 -Actual (Get-Tally -Name 'kept') -Message 'and the global counter was not added to'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
Add-Tally -Name 'Passed'
Add-Tally -Name 'passed'
Add-Tally -Name 'PASSED'

# Assert
Assert-Equal -Expected 3 -Actual (Get-Tally -Name 'passed') `
    -Message 'Names are not case-sensitive, so all three spellings are one counter'
Assert-Equal -Expected @('Passed') -Actual @((Get-Tally).Name) `
    -Message 'and the counter keeps the spelling it was first added with'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
'txt', 'md', 'txt' | Add-Tally

# Assert
Assert-Equal -Expected 2 -Actual (Get-Tally -Name 'txt') `
    -Message 'Names piped in are each counted, so a repeat adds again'
Assert-Equal -Expected 1 -Actual (Get-Tally -Name 'md') -Message 'and a name seen once counts once'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
'a', 'b' | Add-Tally -Amount 5

# Assert
Assert-Equal -Expected @(5, 5) -Actual @((Get-Tally).ForEach('Count')) -Message '-Amount applies to every name piped in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
1, 2, 1 | Add-Tally

# Assert
Assert-Equal -Expected @('1', '2') -Actual @((Get-Tally).Name) -Message 'A number piped in is counted under its text'
Assert-Equal -Expected @(2, 1) -Actual @((Get-Tally).ForEach('Count')) -Message 'once for each time it appears'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
[PSCustomObject]@{ Name = 'seen' }, [PSCustomObject]@{ Name = 'seen' } | Add-Tally

# Assert
Assert-Equal -Expected 2 -Actual (Get-Tally -Name 'seen') `
    -Message 'An object with a Name property is counted under that name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
$noName = { [PSCustomObject]@{ Extension = '.txt' } | Add-Tally }
$dictionary = { @{ Name = 'x' } | Add-Tally }
$given = { Add-Tally -Name ([PSCustomObject]@{ Extension = '.txt' }) }

# Assert
Assert-Throws -ScriptBlock $noName -MessageLike '*Name property*' `
    -Message 'A piped object with no Name property is refused, not counted under its own text'
Assert-Throws -ScriptBlock $dictionary -MessageLike '*Name property*' `
    -Message 'and so is a dictionary, whose keys are not properties'
Assert-Throws -ScriptBlock $given -MessageLike '*Name property*' -Message 'and such an object given as -Name'
Assert-Equal -Expected 0 -Actual @(Get-Tally).Count -Message 'and nothing was counted for any of them'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
$pair = [Collections.Generic.KeyValuePair[string, int]]::new('kv', 3)

# Act
@{ k = 2 }.GetEnumerator() | Add-Tally
$refused = { $pair | Add-Tally }

# Assert
Assert-Throws -ScriptBlock $refused -MessageLike '*KeyValuePair*Name property*' `
    -Message 'A piped struct with no Name property is refused, not counted under its own text'
Assert-Equal -Expected '1 k' -Actual (Format-Tally) `
    -Message 'and a piped dictionary entry is counted once under its key'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
[PSCustomObject]@{ Name = 'x'; Count = $null } | Add-Tally
$notANumber = { [PSCustomObject]@{ Name = 'y'; Count = 'many' } | Add-Tally }

# Assert
Assert-Equal -Expected '0 x' -Actual (Format-Tally) `
    -Message 'A piped Count of $null adds nothing, but creates the counter at zero'
Assert-Throws -ScriptBlock $notANumber -MessageLike "*parameter 'Amount'*" `
    -Message 'and a Count that is not a number is a binding error on -Amount'
Assert-Equal -Expected '0 x' -Actual (Format-Tally) -Message 'which adds nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
$sandbox = Join-Path ([IO.Path]::GetTempPath()) "tally-$([guid]::NewGuid())"
$null = New-Item -ItemType Directory -Path (Join-Path $sandbox 'src')
Set-Content -LiteralPath (Join-Path $sandbox 'a.txt') -Value 'a'
Set-Content -LiteralPath (Join-Path $sandbox 'b.txt') -Value 'b'
Set-Content -LiteralPath (Join-Path $sandbox 'LICENSE') -Value 'l'

# Act
try {
    Get-ChildItem -LiteralPath $sandbox -File | Where-Object Extension | ForEach-Object Extension | Add-Tally
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force
}

# Assert
Assert-Equal -Expected '2 .txt' -Actual (Format-Tally) `
    -Message 'The help''s extension count skips folders and files with no extension'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
Read-Tally -Text '5 passed - 2 failed' | Add-Tally

# Assert
Assert-Equal -Expected '5 passed - 2 failed' -Actual (Format-Tally) `
    -Message 'Read-Tally output piped in adds each entry''s Count, not one per entry'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Clear-Tally -Key 'copy'
Add-Tally -Name 'a' -Amount 4
Add-Tally -Name 'b' -Amount 2

# Act
Get-Tally | Add-Tally -Key 'copy'

# Assert
Assert-Equal -Expected '4 a - 2 b' -Actual (Format-Tally -Key 'copy') `
    -Message 'Get-Tally output piped in copies every counter at its count'
Clear-Tally -Key 'copy'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
[PSCustomObject]@{ Name = 'a'; Count = 3 }, 'b', [PSCustomObject]@{ Name = 'c' } | Add-Tally

# Assert
Assert-Equal -Expected '3 a - 1 b - 1 c' -Actual (Format-Tally) `
    -Message 'A piped item with no Count adds one, even after an item that had one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
$whitespace = { Add-Tally -Name '   ' }
$leading = { Add-Tally -Name ' padded' }
$trailing = { Add-Tally -Name 'padded ' }
$twoLines = { Add-Tally -Name "two`nlines" }

# Assert
Assert-Throws -ScriptBlock $whitespace -MessageLike '*one line*no leading or trailing whitespace*' `
    -Message 'A name of only whitespace is refused, with the rule'
Assert-Throws -ScriptBlock $leading -MessageLike '*one line*' -Message 'A name with leading whitespace is refused'
Assert-Throws -ScriptBlock $trailing -MessageLike '*one line*' -Message 'A name with trailing whitespace is refused'
Assert-Throws -ScriptBlock $twoLines -MessageLike '*one line*' -Message 'A name spanning lines is refused'
Assert-Equal -Expected 0 -Actual @(Get-Tally).Count -Message 'and nothing was counted for any of them'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
$lineSeparator = { Add-Tally -Name "a$([char]0x2028)b" }
$paragraphSeparator = { Add-Tally -Name "a$([char]0x2029)b" }
$nextLine = { Add-Tally -Name "a$([char]0x0085)b" }
$verticalTab = { Add-Tally -Name "a$([char]0x0B)b" }
$formFeed = { Add-Tally -Name "a$([char]0x0C)b" }

# Assert
Assert-Throws -ScriptBlock $lineSeparator -MessageLike '*one line*' -Message 'A Unicode line separator is a line break'
Assert-Throws -ScriptBlock $paragraphSeparator -MessageLike '*one line*' -Message 'and so is a paragraph separator'
Assert-Throws -ScriptBlock $nextLine -MessageLike '*one line*' -Message 'and a next-line character'
Assert-Throws -ScriptBlock $verticalTab -MessageLike '*one line*' -Message 'and a vertical tab'
Assert-Throws -ScriptBlock $formFeed -MessageLike '*one line*' -Message 'and a form feed'
Assert-Equal -Expected 0 -Actual @(Get-Tally).Count -Message 'and nothing was counted for any of them'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act - eight runspaces adding at once
1..8 | ForEach-Object -ThrottleLimit 8 -TimeoutSeconds 120 -Parallel {
    Import-Module $using:modulePath
    1..100 | ForEach-Object { Add-Tally -Name 'hits' }
}

# Assert
Assert-Equal -Expected 800 -Actual (Get-Tally -Name 'hits') `
    -Message 'Counts added from several runspaces are all counted, none lost'
Clear-Tally

exit (Complete-TestRun)
