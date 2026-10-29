#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

# Copies one value with a fresh context, keeping an array whole.
$copy = {
    param($Node, [bool]$KeyedByData, [string[]]$KeepKeysOf)
    , (ConvertTo-PascalCaseNode -Node $Node -Context (New-GitHubJsonContext -KeepKeysOf $KeepKeysOf) -KeyedByData $KeyedByData)
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a list holding an object, a list, and scalars
$when = [datetime]::new(2024, 1, 2)
$list = & $module $copy @([PSCustomObject]@{ node_id = 'n' }, @(), 'x', 5, $when, $null) $false

# Assert
Assert-Equal -Expected 6 -Actual $list.Count -Message 'A list is copied element by element, a null included'
Assert-Equal -Expected 'n' -Actual $list[0].NodeId -Message 'with an object in it re-cased'
Assert-That -Condition ($list[1] -is [array] -and $list[1].Count -eq 0) -Message 'and a list in it kept whole'
Assert-Equal -Expected @('x', 5, $when, $null) -Actual @($list[2], $list[3], $list[4], $list[5]) `
    -Message 'Scalars, a date among them, are returned as they are'

#───────────────────────────────────────────────────────────────────────────────
# Act - an object keyed by data
$keyed = & $module $copy ([PSCustomObject]@{ 'a_b.txt' = [PSCustomObject]@{ raw_url = 'u' } }) $true

# Assert
Assert-That -Condition ($keyed -is [System.Collections.Specialized.OrderedDictionary]) `
    -Message 'An object keyed by data becomes an ordered dictionary'
Assert-Equal -Expected @('a_b.txt') -Actual @($keyed.PSBase.Keys) -Message 'with its keys as they are'
Assert-Equal -Expected 'u' -Actual $keyed['a_b.txt'].RawUrl -Message 'and what they hold re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Act - a dictionary whose value names a kept key, and an object of another kind
$table = & $module $copy @{ files = @{ 'x_y' = 1 }; plain_key = 2 } $false @('files')
$other = & $module $copy ([System.Text.StringBuilder]::new('sb')) $false

# Assert
Assert-Equal -Expected @('x_y') -Actual @($table.Files.PSBase.Keys) `
    -Message 'A dictionary''s keys are matched against the kept names too'
Assert-Equal -Expected 2 -Actual $table.PlainKey -Message 'and its other keys re-cased'
Assert-That -Condition ($other -is [System.Text.StringBuilder]) `
    -Message 'An object that is neither a PSCustomObject nor a dictionary is returned as it is'

exit (Complete-TestRun)
