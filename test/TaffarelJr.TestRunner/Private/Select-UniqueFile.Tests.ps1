#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Select-UniqueFile.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two paths that differ only by case, as a case-sensitive file system holds them
$upper = [PSCustomObject]@{ FullName = '/tests/Foo.Tests.ps1' }
$lower = [PSCustomObject]@{ FullName = '/tests/foo.Tests.ps1' }

# Act
$unique = @(Select-UniqueFile -File @($upper, $lower))

# Assert
Assert-Equal -Expected 2 -Actual $unique.Count -Message 'Two paths that differ only by case are two files'
Assert-That -Condition ($unique.FullName -ccontains '/tests/Foo.Tests.ps1') -Message 'The upper-case name is kept'
Assert-That -Condition ($unique.FullName -ccontains '/tests/foo.Tests.ps1') -Message 'and so is the lower-case one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same file found twice, and another file
$again = [PSCustomObject]@{ FullName = '/tests/Foo.Tests.ps1' }
$other = [PSCustomObject]@{ FullName = '/tests/Bar.Tests.ps1' }

# Act
$deduped = @(Select-UniqueFile -File @($upper, $other, $again))

# Assert
Assert-Equal -Expected @('/tests/Bar.Tests.ps1', '/tests/Foo.Tests.ps1') -Actual @($deduped.FullName) `
    -Message 'A file found twice is returned once, and the files come back sorted by path'

#───────────────────────────────────────────────────────────────────────────────
# Act
$none = @(Select-UniqueFile -File @())

# Assert
Assert-Equal -Expected 0 -Actual $none.Count -Message 'No files give nothing'

exit (Complete-TestRun)
