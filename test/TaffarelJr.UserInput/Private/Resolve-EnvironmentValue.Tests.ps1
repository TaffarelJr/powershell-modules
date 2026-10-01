#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
$module = Get-Module TaffarelJr.UserInput
$resolve = { param($value) Resolve-EnvironmentValue -InputObject $value }

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that stand for their own text
$simple = @(
    @{ Name = 'a string'; Value = 'text'; Expected = 'text' }
    @{ Name = 'a string with spaces around it'; Value = '  text  '; Expected = '  text  ' }
    @{ Name = 'an empty string'; Value = ''; Expected = '' }
    @{ Name = '$null'; Value = $null; Expected = '' }
    @{ Name = 'an integer'; Value = 42; Expected = '42' }
    @{ Name = 'a decimal'; Value = [decimal]1.5; Expected = '1.5' }
    @{ Name = 'a boolean'; Value = $true; Expected = 'True' }
    @{ Name = 'a character'; Value = [char]'x'; Expected = 'x' }
    @{ Name = 'an enum value'; Value = [DayOfWeek]::Friday; Expected = 'Friday' }
)

foreach ($case in $simple) {
    # Act
    $text = & $module $resolve $case.Value

    # Assert
    Assert-Equal -Expected $case.Expected -Actual $text -Message "$($case.Name) is its own text"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$withText = [PSCustomObject]@{ Name = 'X'; Value = 'from the property' }
$withNumber = [PSCustomObject]@{ Name = 'X'; Value = 42 }
$withNothing = [PSCustomObject]@{ Name = 'X'; Value = $null }

# Act
$fromText = & $module $resolve $withText
$fromNumber = & $module $resolve $withNumber
$fromNothing = & $module $resolve $withNothing

# Assert
Assert-Equal -Expected 'from the property' -Actual $fromText -Message 'An object is read from its Value property'
Assert-Equal -Expected '42' -Actual $fromNumber -Message 'as text, whatever type the property holds'
Assert-Equal -Expected '' -Actual $fromNothing -Message 'and a $null property is an empty value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values with no Value property
$without = @(
    @{ Name = 'an object with other properties'; Value = [PSCustomObject]@{ Name = 'X' }; Type = 'PSCustomObject' }
    @{ Name = 'a date'; Value = [datetime]::Now; Type = 'DateTime' }
    @{ Name = 'a hashtable'; Value = @{ Value = 'v' }; Type = 'Hashtable' }
    @{ Name = 'an array'; Value = @('a', 'b'); Type = 'Object[]' }
)

foreach ($case in $without) {
    # Act / Assert
    Assert-Throws -ScriptBlock { & $module $resolve $case.Value } `
        -MessageLike ("Cannot read an environment variable's value from a " +
            "$([WildcardPattern]::Escape("[$($case.Type)]")):*") `
        -Message "$($case.Name) is refused, naming its type"
}

exit (Complete-TestRun)
