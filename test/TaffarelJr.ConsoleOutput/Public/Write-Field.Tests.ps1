#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = Get-HostOutput { Write-Field -Name 'Branch' -Value 'main' }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'Write-Field prints exactly one line'
Assert-That -Condition ($lines[0] -like '*Branch:*') -Message 'The line carries the field name'
Assert-That -Condition ($lines[0] -like '*main*') -Message 'The line carries the field value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a name longer than the alignment budget
# still leaves a space before the value instead of crowding it
$long = Get-HostOutput { Write-Field -Name 'AVeryLongFieldName' -Value 'x' }

# Assert
Assert-That -Condition ($long[0] -like '*AVeryLongFieldName: x*') -Message 'An overlong name still gets a separating space before its value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - empty name prints the value alone, as a continuation
$continuation = Get-HostOutput { Write-Field -Name '' -Value 'more detail' }

# Assert
Assert-That -Condition ($continuation[0] -like '*more detail*') -Message 'An empty name still prints the value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - binds by property name,
# so a stream of Name/Value objects (like Get-ChildItem Env:)
# can be piped straight through
$objects = @(
    [PSCustomObject]@{ Name = 'One'; Value = '1' }
    [PSCustomObject]@{ Name = 'Two'; Value = '2' }
)
$piped = Get-HostOutput { $objects | Write-Field }

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two Name/Value objects prints two lines'
Assert-That -Condition ($piped[0] -like '*One:*1*') -Message 'The first piped object renders its own name and value'
Assert-That -Condition ($piped[1] -like '*Two:*2*') -Message 'The second piped object renders its own name and value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Budget customizes the alignment column width
$narrow = Get-HostOutput { Write-Field -Name 'x' -Value 'y' -Budget 5 }
$prefixLength = ([Regex]::Match($narrow[0], '^ *')).Length
$valueIndex = $narrow[0].IndexOf('y')

# Assert
Assert-Equal -Expected ($prefixLength + 5) -Actual $valueIndex -Message 'The value starts exactly -Budget columns after the indent'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Indent overrides the ambient indent
$plain = Get-HostOutput { Write-Field -Name 'x' -Value 'y' }
$overridden = Get-HostOutput { Write-Field -Name 'x' -Value 'y' -Indent 4 }
$plainIndent = ([Regex]::Match($plain[0], '^ *')).Length
$overriddenIndent = ([Regex]::Match($overridden[0], '^ *')).Length

# Assert
Assert-Equal -Expected ($plainIndent + 4) -Actual $overriddenIndent -Message '-Indent 4 adds four spaces on top of the default'

exit (Complete-TestRun)
