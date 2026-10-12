#Requires -Version 7.4
using namespace System.Collections.Generic

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Get-DictionaryValue.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Equal -Expected 'p' -Actual (Get-DictionaryValue -Dictionary @{ Path = 'p' } -Name 'Path') `
    -Message 'An entry named exactly is found'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a dictionary whose own lookup is case-sensitive
$exact = [Dictionary[string, object]]::new()
$exact['path'] = 'p'

# Act / Assert
Assert-Equal -Expected 'p' -Actual (Get-DictionaryValue -Dictionary $exact -Name 'Path') `
    -Message 'An entry in other casing is found, even where the dictionary''s own lookup is case-sensitive'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same name twice, in two casings
$twice = [Dictionary[string, object]]::new()
$twice['PATH'] = 'first'
$twice['path'] = 'second'

# Act / Assert
Assert-Equal -Expected 'first' -Actual (Get-DictionaryValue -Dictionary $twice -Name 'Path') `
    -Message 'The first matching entry wins'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - keys that are not strings, one of them a relative Uri that -eq
# reports equal to 'Path'
$numbered = [Dictionary[int, object]]::new()
$numbered[1] = 'p'
$mixed = [ordered]@{}
$mixed[[uri]::new('Path', [UriKind]::Relative)] = 'uri'
$mixed['Path'] = 'p'

# Act
$fromNumbered = @(Get-DictionaryValue -Dictionary $numbered -Name 'Path')
$fromMixed = Get-DictionaryValue -Dictionary $mixed -Name 'Path'

# Assert
Assert-Equal -Expected 0 -Actual $fromNumbered.Count `
    -Message 'A dictionary keyed by numbers gives nothing, rather than throwing on the lookup'
Assert-Equal -Expected 'p' -Actual $fromMixed `
    -Message 'A key that is not a string is skipped, even one PowerShell would call equal to the name, and the string key after it found'

#───────────────────────────────────────────────────────────────────────────────
# Act
$missing = @(Get-DictionaryValue -Dictionary @{ Name = 'n' } -Name 'Path')

# Assert
Assert-Equal -Expected 0 -Actual $missing.Count -Message 'A name the dictionary does not hold gives nothing'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Equal -Expected 'k' -Actual (Get-DictionaryValue -Dictionary @{ Keys = 'k'; Path = 'p' } -Name 'Keys') `
    -Message 'An entry named Keys is found like any other'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock {
    Get-DictionaryValue -Dictionary 'not a dictionary' -Name 'Path'
} -MessageLike '*Dictionary*' -Message 'Something that is not a dictionary is refused'

exit (Complete-TestRun)
