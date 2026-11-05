#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Get-CoverageReportPath.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$output = Join-Path ([System.IO.Path]::GetTempPath()) 'out'

# Act
$path = Get-CoverageReportPath -OutputPath $output -Name 'Module/Public/Write-Success'

# Assert
$expected = Join-Path $output 'Module' 'Public' 'Write-Success.cobertura.xml'
Assert-Equal -Expected $expected -Actual $path `
    -Message 'Converts forward slashes to the platform separator and appends .cobertura.xml'

exit (Complete-TestRun)
