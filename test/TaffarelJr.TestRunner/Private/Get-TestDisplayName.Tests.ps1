#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Get-TestDisplayName.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a nested file
$name = Get-TestDisplayName -TestRoot 'C:\repo\test' -File 'C:\repo\test\Module\Public\Write-Success.Tests.ps1'

# Assert
Assert-Equal -Expected 'Module/Public/Write-Success' -Actual $name -Message 'Strips the suffix and converts to forward slashes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a file directly under the root
$rootName = Get-TestDisplayName -TestRoot 'C:\repo\test' -File 'C:\repo\test\Top.Tests.ps1'

# Assert
Assert-Equal -Expected 'Top' -Actual $rootName -Message 'A file directly under the root has no leading slash'

exit (Complete-TestRun)
