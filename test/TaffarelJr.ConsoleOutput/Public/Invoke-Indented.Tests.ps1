#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Read by the script block or child process the test hands it to, by scope.')]
param()

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
$during = Invoke-Indented -Width 5 -ScriptBlock { Get-Indent }

# Assert
Assert-Equal -Expected 5 -Actual $during -Message 'The script block runs with the indent pushed'
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'The indent is popped after the script block returns'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - default width
$default = Invoke-Indented -ScriptBlock { Get-Indent }

# Assert
Assert-Equal -Expected 2 -Actual $default -Message 'Invoke-Indented defaults to a width of 2'
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'The indent is popped after the default-width block too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - regions nest
$nested = Invoke-Indented -Width 3 { Invoke-Indented -Width 4 { Get-Indent } }

# Assert
Assert-Equal -Expected 7 -Actual $nested -Message 'Nested regions add up'
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'and both are popped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
$assigned = 'before'

# Act - the block runs in the caller's own scope
Invoke-Indented { $assigned = 'inside' }

# Assert
Assert-Equal -Expected 'inside' -Actual $assigned `
    -Message 'A variable the block assigns is the caller''s variable, as with ForEach-Object'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act
$output = @(Invoke-Indented { 'one'; 'two' })
$returned = Invoke-Indented { return 'early'; 'unreached' }

# Assert
Assert-Equal -Expected @('one', 'two') -Actual $output -Message 'What the block writes comes out of Invoke-Indented'
Assert-Equal -Expected 'early' -Actual $returned -Message 'and a return inside the block ends only the block'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act / Assert - the block throws
Assert-Throws -ScriptBlock { Invoke-Indented -ScriptBlock { throw 'boom' } } -MessageLike 'boom' `
    -Message 'Invoke-Indented does not swallow the exception its script block throws'
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'The indent is popped even when the script block throws'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a block that pushes a level of its own, then throws before popping it
Reset-ConsoleOutputState -Module $module
Push-Indent -Width 3
$block = { Invoke-Indented { Push-Indent 4; throw 'boom' } }

# Act
$warnings = @(Get-WarningOutput {
        Assert-Throws -ScriptBlock $block -MessageLike 'boom' -Message 'The block''s exception still reaches the caller'
    })
$after = Get-Indent

# Assert
Assert-Equal -Expected 3 -Actual $after `
    -Message 'A level the block left behind is popped too, back to the caller''s indent'
Assert-Equal -Expected @(
    'Invoke-Indented: the script block pushed 1 indent level(s) more than it popped; ' +
    'the indent is put back to where the block started.'
) -Actual $warnings -Message 'and the unbalanced block is reported'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a block that pops one level more than it pushed
Reset-ConsoleOutputState -Module $module
Push-Indent -Width 3

# Act
$warnings = @(Get-WarningOutput { Invoke-Indented { Pop-Indent } })
$after = Get-Indent

# Assert
Assert-Equal -Expected 3 -Actual $after -Message 'The caller''s own level survives a block that pops too many'
Assert-Equal -Expected @(
    'Invoke-Indented: the script block popped 1 indent level(s) more than it pushed; ' +
    'the indent is put back to where the block started.'
) -Actual $warnings -Message 'and the unbalanced block is reported'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a balanced block inside an outer level
Reset-ConsoleOutputState -Module $module
Push-Indent -Width 3

# Act
$warnings = @(Get-WarningOutput { Invoke-Indented { Push-Indent 1; Pop-Indent } })
$after = Get-Indent

# Assert
Assert-Equal -Expected 3 -Actual $after -Message 'A balanced block leaves the caller''s indent as it was'
Assert-Equal -Expected 0 -Actual $warnings.Count -Message 'and reports nothing'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a negative width
Assert-Throws -ScriptBlock { Invoke-Indented -Width -1 -ScriptBlock { 'x' } } -MessageLike '*Width*' `
    -Message 'A negative width is refused'

exit (Complete-TestRun)
