#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
$module = Get-Module TaffarelJr.UserInput

#───────────────────────────────────────────────────────────────────────────────
# Act
$record = & $module { New-CallMistakeError -Message 'the call is wrong' -ErrorId 'SomeMistake' -TargetObject 42 }

# Assert
Assert-Equal -Expected 'the call is wrong' -Actual $record.Exception.Message -Message 'The message is the one given'
Assert-That -Condition ($record.Exception -is [ArgumentException]) -Message 'carried by an ArgumentException'
Assert-Equal -Expected 'SomeMistake' -Actual $record.FullyQualifiedErrorId -Message 'The id is the one given'
Assert-Equal -Expected 'InvalidArgument' -Actual "$($record.CategoryInfo.Category)" `
    -Message 'and the category says the argument is wrong'
Assert-Equal -Expected 42 -Actual $record.TargetObject -Message 'The value that is wrong comes with it'

exit (Complete-TestRun)
