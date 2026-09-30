#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Get-TestResultPath.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$path = Get-TestResultPath -OutputPath 'C:\out' -Name 'Module/Public/Write-Success'

# Assert
$expected = Join-Path 'C:\out' 'Module\Public\Write-Success.junit.xml'
Assert-Equal -Expected $expected -Actual $path -Message 'Converts forward slashes to the platform separator and appends .junit.xml'

exit (Complete-TestRun)
