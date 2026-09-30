#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Get-Module TaffarelJr.TestKit

$cases = @(
    @{ Name = 'an int'; Value = 5; IsNumber = $true }
    @{ Name = 'a byte'; Value = [byte]5; IsNumber = $true }
    @{ Name = 'an unsigned long'; Value = [ulong]5; IsNumber = $true }
    @{ Name = 'a double'; Value = 0.5; IsNumber = $true }
    @{ Name = 'a float'; Value = [float]0.5; IsNumber = $true }
    @{ Name = 'a decimal'; Value = [decimal]0.5; IsNumber = $true }
    @{ Name = 'a boolean'; Value = $true; IsNumber = $false }
    @{ Name = 'a char'; Value = [char]'a'; IsNumber = $false }
    @{ Name = 'a pointer'; Value = [IntPtr]5; IsNumber = $false }
    @{ Name = 'an unsigned pointer'; Value = [UIntPtr]5; IsNumber = $false }
    @{ Name = 'a big integer'; Value = [bigint]5; IsNumber = $false }
    @{ Name = 'a 128-bit integer'; Value = [Int128]5; IsNumber = $false }
    @{ Name = 'an unsigned 128-bit integer'; Value = [UInt128]5; IsNumber = $false }
    @{ Name = 'a half'; Value = [Half]1.5; IsNumber = $false }
    @{ Name = 'a number as a string'; Value = '5'; IsNumber = $false }
    @{ Name = 'an enum value'; Value = [DayOfWeek]::Monday; IsNumber = $false }
    @{ Name = '$null'; Value = $null; IsNumber = $false }
)

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - every kind of value in the table
foreach ($case in $cases) {
    $result = & $module { param($Value) Test-NumberType -Value $Value } $case.Value
    Assert-Equal -Expected $case.IsNumber -Actual $result -Message "Whether $($case.Name) is a number"
}

exit (Complete-TestRun)
