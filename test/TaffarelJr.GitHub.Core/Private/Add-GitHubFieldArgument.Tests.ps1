#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

# Adds one field to a new list and returns the list's contents.
$add = {
    param([string]$Parent, [string]$Key, $Value)
    $arguments = [System.Collections.Generic.List[string]]::new()
    Add-GitHubFieldArgument -Arguments $arguments -Flag '--field' -Parent $Parent -Key $Key -Value $Value
    , $arguments.ToArray()
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a top-level field, one inside another, and a nested hashtable
$top = & $module $add '' 'title' 'T'
$inner = & $module $add 'outer' 'title' 'T'
$nested = & $module $add '' 'a' @{ b = @{ c = 1 }; d = @() }

# Assert
Assert-Equal -Expected @('--field', 'title=T') -Actual $top -Message 'A top-level field is its key and value'
Assert-Equal -Expected @('--field', 'outer[title]=T') -Actual $inner `
    -Message 'A field inside another is bracketed under it'
Assert-Equal -Expected @('--field', 'a[b][c]=1', '--field', 'a[d][]') -Actual $nested `
    -Message 'Nesting gives one bracket per level, and an empty list a bare key[]'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - keys and values gh's syntax cannot carry
Assert-Throws -ScriptBlock {
    & $module $add 'outer' 'k=v' 1
} -MessageLike "*Field key 'k=v' holds*" -Message 'A key holding = throws'
Assert-Throws -ScriptBlock {
    & $module $add 'outer' 'empty' @{}
} -MessageLike "*Field 'outer``[empty``]' is an empty hashtable*" `
    -Message 'An empty hashtable throws, with its full name'
Assert-Throws -ScriptBlock {
    & $module $add '' 'items' @(, @(1))
} -MessageLike "*Field 'items' holds a list of objects or lists*" -Message 'A list of lists throws'

exit (Complete-TestRun)
