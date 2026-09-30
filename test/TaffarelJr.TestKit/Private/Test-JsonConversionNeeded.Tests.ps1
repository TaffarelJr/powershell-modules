#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Get-Module TaffarelJr.TestKit

$cases = @(
    @{ Name = '$null'; Value = $null; Needed = $false }
    @{ Name = 'a string'; Value = 'a'; Needed = $false }
    @{ Name = 'an int'; Value = 5; Needed = $false }
    @{ Name = 'a big integer'; Value = [bigint]5; Needed = $true }
    @{ Name = 'a list of ints'; Value = @(1, 2, 3); Needed = $false }
    @{ Name = 'a byte array'; Value = [byte[]](1, 2); Needed = $false }
    @{ Name = 'a list holding a half'; Value = @(1, [Half]1.5); Needed = $true }
    @{ Name = 'a list holding $null and a pointer'; Value = @($null, [IntPtr]1); Needed = $true }
    @{ Name = 'a hashtable holding an Int128'; Value = @{ a = [Int128]1 }; Needed = $true }
    @{ Name = 'an object holding a UInt128'; Value = [PSCustomObject]@{ a = [UInt128]1 }; Needed = $true }
    @{ Name = 'an object holding plain values'; Value = [PSCustomObject]@{ a = 1; b = 'x' }; Needed = $false }
    @{ Name = 'an XML document'; Value = [xml]'<a>1</a>'; Needed = $false }
    @{ Name = 'a big integer at depth 4'; Value = , (, (, @([bigint]1))); Needed = $true }
    @{ Name = 'a big integer at depth 5'; Value = , (, (, (, @([bigint]1)))); Needed = $false }
    @{
        Name = 'an unsigned pointer in an object at depth 4'
        Value = @{ a = @{ b = @{ c = [PSCustomObject]@{ d = [UIntPtr]1 } } } }
        Needed = $true
    }
)

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - every kind of value in the table
foreach ($case in $cases) {
    $needed = & $module { param($Value) Test-JsonConversionNeeded -Value $Value } $case.Value
    Assert-Equal -Expected $case.Needed -Actual $needed -Message "Whether $($case.Name) needs converting"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$self = @{}
$self.me = $self

# Act
$selfNeeded = & $module { param($Value) Test-JsonConversionNeeded -Value $Value } $self
$startedDeep = & $module { Test-JsonConversionNeeded -Value @([bigint]1) -Depth 4 }

# Assert
Assert-Equal -Expected $false -Actual $selfNeeded `
    -Message 'A hashtable that contains itself is looked through only so deep, and the walk ends'
Assert-Equal -Expected $false -Actual $startedDeep `
    -Message 'A list already as deep as JSON writes as text is not looked into'

exit (Complete-TestRun)
