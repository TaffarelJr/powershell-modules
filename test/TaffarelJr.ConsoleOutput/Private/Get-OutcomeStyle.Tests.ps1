#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$names = 'Success', 'Skip', 'Warn', 'Failure', 'Info', 'Detail', 'Stopped'

# Act
$styles = foreach ($name in $names) {
    & $module { param($n) Get-OutcomeStyle -Outcome $n } $name
}

# Assert
Assert-Equal -Expected @('done', 'already done', 'warning', 'failed', '', '', 'stopped') -Actual @($styles.Wording) `
    -Message 'Each outcome has its default wording'
Assert-Equal -Expected @('Green', 'DarkGray', 'Yellow', 'Red', 'Gray', 'DarkGray', 'Yellow') `
    -Actual @($styles.Color | ForEach-Object { "$_" }) -Message 'and its color'
Assert-Equal -Expected @('✅ ', '⏭️  ', '⚠️  ', '❌ ', 'ℹ️  ', '   ', '⚠️  ') -Actual @($styles.Marker) `
    -Message 'and its marker, trailing space included'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { & $module { Get-OutcomeStyle -Outcome 'Done' } } -MessageLike '*Outcome*' `
    -Message 'An outcome that does not exist is refused'

exit (Complete-TestRun)
