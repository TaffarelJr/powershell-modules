#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Get-Module TaffarelJr.TestKit

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a boolean as Test-Path hands it back, wrapped
$wrapped = Test-Path -LiteralPath $PSScriptRoot

# Act
$unwrapped = & $module { param($Value) Get-BaseValue $Value } $wrapped

# Assert
Assert-That -Condition ($wrapped -is [pscustomobject]) `
    -Message 'Precondition: a cmdlet''s boolean passes for a custom object'
Assert-That -Condition ($unwrapped -isnot [pscustomobject]) -Message 'Unwrapped, it no longer does'
Assert-Equal -Expected 'System.Boolean' -Actual $unwrapped.GetType().FullName -Message 'It is the boolean underneath'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$plain = & $module { Get-BaseValue 'text' }

# Assert
Assert-Equal -Expected 'text' -Actual $plain -Message 'A plain value is returned unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$nothing = & $module { Get-BaseValue $null }

# Assert
Assert-That -Condition ($null -eq $nothing) -Message '$null stays $null'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$one = & $module { $value = Get-BaseValue @('a'); , $value }
$empty = & $module { $value = Get-BaseValue @(); , $value }

# Assert
Assert-That -Condition ($one -is [array] -and $one.Count -eq 1) -Message 'A one-element array stays an array'
Assert-That -Condition ($empty -is [array] -and $empty.Count -eq 0) -Message 'An empty array stays an array'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$object = [PSCustomObject]@{ Name = 'x' }

# Act
$kept = & $module { param($Value) Get-BaseValue $Value } $object

# Assert
Assert-That -Condition ($kept -is [pscustomobject] -and $kept.Name -eq 'x') `
    -Message 'A genuine custom object is left as it is'

exit (Complete-TestRun)
