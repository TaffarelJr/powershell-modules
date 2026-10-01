#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - shadow Read-Host -AsSecureString
# so no test here waits on a real person.
# Global scope for the same reason as Read-Input.Tests.ps1.
$global:readHostSecretAnswer = ''
function global:Read-Host {
    param(
        [Parameter(Position = 0)]
        [string]$Prompt,
        [switch]$AsSecureString
    )
    return (ConvertTo-SecureString -String $global:readHostSecretAnswer -AsPlainText -Force)
}

# Arrange / Act - a typed secret is returned exactly as typed, untrimmed
$global:readHostSecretAnswer = '  s3cr3t  '
$result = Read-Secret -Prompt 'Token'

# Assert
Assert-Equal -Expected '  s3cr3t  ' -Actual $result -Message 'A secret is returned untrimmed, unlike Read-Input'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Hint lines print before the prompt
$global:readHostSecretAnswer = 'anything'
$lines = Get-HostOutput { Read-Secret -Prompt 'Token' -Hint @('line one') }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message '-Hint prints before the prompt'
Assert-That -Condition ($lines[0] -like '*line one*') -Message 'The hint line is printed'

exit (Complete-TestRun)
