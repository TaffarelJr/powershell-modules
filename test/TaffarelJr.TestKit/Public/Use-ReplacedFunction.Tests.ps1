#Requires -Version 7.4

using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis

[SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Read by the script block the test hands to the function, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force

# A module of the test's own, with a public function that calls a private one.
$subject = New-Module -Name ReplacedFunctionProbe -ScriptBlock {
    function Get-Secret {
        <#
        .SYNOPSIS
            The private helper the test replaces.
        #>
        param([string]$Name)
        "real secret for $Name"
    }

    function Get-Report {
        <#
        .SYNOPSIS
            The public function that calls the helper.
        #>
        param([string]$Name)
        "report: $(Get-Secret -Name $Name)"
    }

    Export-ModuleMember -Function Get-Report
} | Import-Module -PassThru

try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $calls = [List[object]]::new()

    # Act
    $during = Use-ReplacedFunction -Module $subject -Name 'Get-Secret' `
        -Body { $calls.Add(@($args)); 'stubbed' } `
        -ScriptBlock { Get-Report -Name 'alpha' }
    $after = Get-Report -Name 'alpha'

    # Assert
    Assert-Equal -Expected 'report: stubbed' -Actual $during `
        -Message 'While the block runs, the module''s own call reaches the stub'
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'and the stub was called once'
    Assert-Equal -Expected @('-Name', 'alpha') -Actual $calls[0] `
        -Message 'with the arguments the module passed'
    Assert-Equal -Expected 'report: real secret for alpha' -Actual $after `
        -Message 'Afterwards the original function is back'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - the module given by name
    $byName = Use-ReplacedFunction -Module 'ReplacedFunctionProbe' -Name 'Get-Secret' `
        -Body { 'by name' } -ScriptBlock { Get-Report -Name 'x' }

    # Assert
    Assert-Equal -Expected 'report: by name' -Actual $byName -Message 'A module name is resolved to the loaded module'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - the block throws
    Assert-Throws -ScriptBlock {
        Use-ReplacedFunction -Module $subject -Name 'Get-Secret' -Body { 'stub' } -ScriptBlock { throw 'boom' }
    } -MessageLike 'boom' -Message 'What the block throws reaches the caller'

    # Assert
    Assert-Equal -Expected 'report: real secret for alpha' -Actual (Get-Report -Name 'alpha') `
        -Message 'and the original function is restored all the same'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a stub that throws
    Assert-Throws -ScriptBlock {
        Use-ReplacedFunction -Module $subject -Name 'Get-Secret' -Body { throw 'stub failed' } `
            -ScriptBlock { Get-Report -Name 'alpha' }
    } -MessageLike 'stub failed' -Message 'What the stub throws reaches the caller through the module'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - the block writes several items
    $items = @(Use-ReplacedFunction -Module $subject -Name 'Get-Secret' -Body { 's' } -ScriptBlock { 'a'; 'b' })

    # Assert
    Assert-Equal -Expected @('a', 'b') -Actual $items -Message 'The block''s output is passed on one item at a time'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $assigned = 'before'

    # Act
    Use-ReplacedFunction -Module $subject -Name 'Get-Secret' -Body { 's' } -ScriptBlock { $assigned = 'inside' }

    # Assert
    Assert-Equal -Expected 'inside' -Actual $assigned `
        -Message 'The block runs in the caller''s scope, so a variable it assigns is the caller''s'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - names the module does not define, and a module name that is not loaded
    Assert-Throws -ScriptBlock {
        Use-ReplacedFunction -Module $subject -Name 'Get-NoSuchThing' -Body { 's' } -ScriptBlock { 'x' }
    } -MessageLike "*defines no function 'Get-NoSuchThing'*" `
        -Message 'A function the module does not define is refused, naming it'
    Assert-Throws -ScriptBlock {
        Use-ReplacedFunction -Module 'NoSuchModuleLoaded' -Name 'Get-Secret' -Body { 's' } -ScriptBlock { 'x' }
    } -MessageLike "*names 0 loaded modules*" `
        -Message 'A module name that is not loaded is refused'
    Assert-Equal -Expected 'report: real secret for alpha' -Actual (Get-Report -Name 'alpha') `
        -Message 'and nothing was replaced'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a replacement inside a replacement
    $nested = Use-ReplacedFunction -Module $subject -Name 'Get-Secret' -Body { 'outer' } -ScriptBlock {
        $inner = Use-ReplacedFunction -Module $subject -Name 'Get-Secret' -Body { 'inner' } `
            -ScriptBlock { Get-Report -Name 'x' }
        "$inner / $(Get-Report -Name 'x')"
    }

    # Assert
    Assert-Equal -Expected 'report: inner / report: outer' -Actual $nested `
        -Message 'A nested replacement restores the outer stub, not the original, when it ends'
}
finally {
    Remove-Module $subject
}

exit (Complete-TestRun)
