#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

# Runs Add-GitHubObjectMember over members built so far and reports the outcome.
$add = {
    param($Members, $Name, $Original, $Value, $Exact, $Originals)
    $context = New-GitHubJsonContext
    $box = $Members
    $nowExact = Add-GitHubObjectMember -Members ([ref]$box) -Name $Name -Original $Original -Value $Value `
        -Exact $Exact `
        -Originals $Originals `
        -Context $context
    [PSCustomObject]@{
        Exact = $nowExact
        Names = @($box.PSBase.Keys)
        Value = $box[$box.PSBase.Count - 1]
        Type  = $box.GetType().Name
        Same  = [object]::ReferenceEquals($box, $Members)
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a name another key already came out as, whose own name is free
$kept = & $module $add ([ordered]@{ AB = 1 }) 'AB' 'a__b' 2 $false @('a_b', 'a__b')

# Assert
Assert-Equal -Expected @('AB', 'a__b') -Actual $kept.Names -Message 'The later key keeps its own name'
Assert-Equal -Expected @($false, $true) -Actual @($kept.Exact, $kept.Same) `
    -Message 'and the object can stay a PSCustomObject'

#───────────────────────────────────────────────────────────────────────────────
# Act - a reserved name, which no PSCustomObject can hold
$reserved = & $module $add ([ordered]@{ a = 1 }) 'PSObject' 'PSObject' 2 $false @('a', 'PSObject')

# Assert
Assert-Equal -Expected @($true, $false, 'OrderedDictionary') `
    -Actual @($reserved.Exact, $reserved.Same, $reserved.Type) `
    -Message 'switches the object to a new dictionary'
Assert-Equal -Expected @('a', 'PSObject') -Actual $reserved.Names -Message 'holding what it had, then the new member'

#───────────────────────────────────────────────────────────────────────────────
# Act - names that differ only in case
$cased = & $module $add ([ordered]@{ FooBar = 1 }) 'FooBar' 'fooBar' 2 $false @('foo_bar', 'fooBar')

# Assert
Assert-Equal -Expected @('FooBar', 'fooBar') -Actual $cased.Names `
    -Message 'are told apart once the object is a case-sensitive dictionary'
Assert-Equal -Expected 2 -Actual $cased.Value -Message 'with the later value under its own name'

#───────────────────────────────────────────────────────────────────────────────
# Act - a later key whose own name is what an earlier key came out as
$renamed = & $module $add ([ordered]@{ Foo = 1 }) 'Foo' 'Foo' 2 $false @('foo', 'Foo')

# Assert
Assert-Equal -Expected @('foo', 'Foo') -Actual $renamed.Names `
    -Message 'The earlier member goes back to its own key''s name, so both are kept'

#───────────────────────────────────────────────────────────────────────────────
# Act - a free name in an object that is already a dictionary
$exact = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
$exact['a'] = 1
$appended = & $module $add $exact 'B' 'b' 2 $true @('a', 'b')

# Assert
Assert-Equal -Expected @($true, $true) -Actual @($appended.Exact, $appended.Same) `
    -Message 'is added to the same dictionary'
Assert-Equal -Expected @('a', 'B') -Actual $appended.Names -Message 'under the name it came out as'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a key the JSON gives twice
Assert-Throws -ScriptBlock {
    & $module $add ([ordered]@{ a = 1 }) 'a' 'a' 2 $false @('a', 'a')
} -MessageLike "A JSON object gives the key 'a' twice, and one of its values would be lost." `
    -Message 'A duplicate key throws instead of losing a value'

#───────────────────────────────────────────────────────────────────────────────
# Act - a clash in an object one of whose members is named Count
$counted = & $module $add ([ordered]@{ Count = 99; FooBar = 2 }) 'FooBar' 'fooBar' 3 $false @(
    'count', 'foo_bar', 'fooBar'
)

# Assert
Assert-Equal -Expected @('Count', 'FooBar', 'fooBar') -Actual $counted.Names `
    -Message 'A member named Count is not taken for the number of members'

exit (Complete-TestRun)
