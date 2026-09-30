#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force

# Arrange - a manifest with a single entry
$singlePath = Join-Path ([System.IO.Path]::GetTempPath()) "$([guid]::NewGuid()).psd1"
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
Assert-Equal -Expected ([version]'5.0.0') -Actual $single[0].MinimumVersion -Message 'Reads and converts MinimumVersion to a [version]'
Assert-Equal -Expected 'https://pester.dev' -Actual $single[0].DocumentationUrl -Message 'Reads the optional DocumentationUrl'

# Arrange - a manifest with two entries, one missing the optional field
$multiPath = Join-Path ([System.IO.Path]::GetTempPath()) "$([guid]::NewGuid()).psd1"
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

# Cleanup
Remove-Item -LiteralPath $singlePath, $multiPath -Force

exit (Complete-TestRun)
