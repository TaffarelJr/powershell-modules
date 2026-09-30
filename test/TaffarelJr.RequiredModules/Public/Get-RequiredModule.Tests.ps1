#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a manifest with a single entry
$singlePath = Join-Path ([Path]::GetTempPath()) "$([Guid]::NewGuid()).psd1"
@'
@{
    Pester = @{
        MinimumVersion   = '5.0.0'
        DocumentationUrl = 'https://pester.dev'
    }
}
'@ | Set-Content -LiteralPath $singlePath

# Act
$single = Get-RequiredModule -Path $singlePath

# Assert
Assert-That -Condition ($single -is [array]) -Message 'A single-entry manifest still returns an array, not a bare object'
Assert-Equal -Expected 1 -Actual $single.Count -Message 'One manifest entry returns one result'
Assert-Equal -Expected 'Pester' -Actual $single[0].Name -Message 'Reads the module name from the manifest key'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $single[0].MinimumVersion -Message 'Reads and converts MinimumVersion to a [Version]'
Assert-Equal -Expected 'https://pester.dev' -Actual $single[0].DocumentationUrl -Message 'Reads the optional DocumentationUrl'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a manifest with two entries, one missing the optional field
$multiPath = Join-Path ([Path]::GetTempPath()) "$([Guid]::NewGuid()).psd1"
@'
@{
    Pester    = @{ MinimumVersion = '5.0.0' }
    PSReadLine = @{ MinimumVersion = '2.0.0'; DocumentationUrl = 'https://example.test' }
}
'@ | Set-Content -LiteralPath $multiPath

# Act
$multi = Get-RequiredModule -Path $multiPath

# Assert
Assert-Equal -Expected 2 -Actual $multi.Count -Message 'Two manifest entries return two results'
Assert-That -Condition ($null -eq ($multi | Where-Object Name -eq 'Pester').DocumentationUrl) -Message 'A missing DocumentationUrl reads as $null, not an error'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a hashtable passed directly, with no .psd1 file at all
$direct = Get-RequiredModule -Data @{
    Pester = @{ MinimumVersion = '5.0.0'; DocumentationUrl = 'https://pester.dev' }
}

# Assert
Assert-Equal -Expected 1 -Actual $direct.Count -Message 'A hashtable manifest is read the same as a file'
Assert-Equal -Expected 'Pester' -Actual $direct[0].Name -Message 'A hashtable manifest reads the module name from its key'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $direct[0].MinimumVersion -Message 'A hashtable manifest reads and converts MinimumVersion to a [Version]'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a hashtable piped in instead of passed as -Data
$piped = @{ Pester = @{ MinimumVersion = '5.0.0' } } | Get-RequiredModule

# Assert
Assert-Equal -Expected 1 -Actual $piped.Count -Message 'A piped hashtable manifest is read the same as -Data'
Assert-Equal -Expected 'Pester' -Actual $piped[0].Name -Message 'A piped hashtable manifest reads the module name from its key'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Path pointing at nothing fails clearly, not with
# whatever error Import-PowerShellDataFile happens to raise
try {
    Get-RequiredModule -Path (Join-Path ([Path]::GetTempPath()) "$([Guid]::NewGuid()).psd1")
    Assert-That -Condition $false -Message 'A missing -Path throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like '*not found*') -Message 'A missing -Path throws, naming the path'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an entry that isn't a hashtable at all
try {
    Get-RequiredModule -Data @{ Pester = '5.0.0' }
    Assert-That -Condition $false -Message 'A non-hashtable entry throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like "*'Pester'*hashtable*") -Message 'A non-hashtable entry throws, naming the module and what was expected'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an entry missing MinimumVersion entirely
try {
    Get-RequiredModule -Data @{ Pester = @{ DocumentationUrl = 'https://pester.dev' } }
    Assert-That -Condition $false -Message 'A missing MinimumVersion throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like "*'Pester'*MinimumVersion*") -Message 'A missing MinimumVersion throws, naming the module'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a MinimumVersion that isn't a valid version at all
try {
    Get-RequiredModule -Data @{ Pester = @{ MinimumVersion = 'not-a-version' } }
    Assert-That -Condition $false -Message 'An invalid MinimumVersion throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like "*'Pester'*not-a-version*") -Message 'An invalid MinimumVersion throws, naming the module and the bad value'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Path and -Data together is ambiguous, not a merge
try {
    Get-RequiredModule -Path $singlePath -Data @{}
    Assert-That -Condition $false -Message '-Path and -Data together throws (did not throw)'
}
catch {
    Assert-That -Condition $true -Message '-Path and -Data together throws'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - neither -Path nor -Data is the same ambiguity
try {
    Get-RequiredModule
    Assert-That -Condition $false -Message 'Neither -Path nor -Data throws (did not throw)'
}
catch {
    Assert-That -Condition $true -Message 'Neither -Path nor -Data throws'
}

# Cleanup
Remove-Item -LiteralPath $singlePath, $multiPath -Force

exit (Complete-TestRun)
