#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/Private/Get-RequiredModuleEntry.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a well-formed entry with both fields
$full = Get-RequiredModuleEntry -Name 'Pester' -Entry @{ MinimumVersion = '5.0.0'; DocumentationUrl = 'https://pester.dev' }

# Assert
Assert-Equal -Expected 'Pester' -Actual $full.Name -Message 'Carries the given name'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $full.MinimumVersion -Message 'Converts MinimumVersion to a [Version]'
Assert-Equal -Expected 'https://pester.dev' -Actual $full.DocumentationUrl -Message 'Carries the optional DocumentationUrl'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - DocumentationUrl is optional
$noUrl = Get-RequiredModuleEntry -Name 'Pester' -Entry @{ MinimumVersion = '5.0.0' }
Assert-That -Condition ($null -eq $noUrl.DocumentationUrl) -Message 'A missing DocumentationUrl reads as $null, not an error'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the entry itself isn't a hashtable at all
try {
    Get-RequiredModuleEntry -Name 'Pester' -Entry '5.0.0'
    Assert-That -Condition $false -Message 'A non-hashtable entry throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like "*'Pester'*hashtable*String*") -Message 'A non-hashtable entry throws, naming the module and the actual type'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the entry is $null
try {
    Get-RequiredModuleEntry -Name 'Pester' -Entry $null
    Assert-That -Condition $false -Message 'A $null entry throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like "*'Pester'*hashtable*") -Message 'A $null entry throws, naming the module'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - MinimumVersion is missing entirely
try {
    Get-RequiredModuleEntry -Name 'Pester' -Entry @{ DocumentationUrl = 'https://pester.dev' }
    Assert-That -Condition $false -Message 'A missing MinimumVersion throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like "*'Pester'*MinimumVersion*") -Message 'A missing MinimumVersion throws, naming the module'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - MinimumVersion doesn't parse as a [Version]
try {
    Get-RequiredModuleEntry -Name 'Pester' -Entry @{ MinimumVersion = 'not-a-version' }
    Assert-That -Condition $false -Message 'An unparseable MinimumVersion throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like "*'Pester'*not-a-version*") -Message 'An unparseable MinimumVersion throws, naming the module and the bad value'
}

exit (Complete-TestRun)
