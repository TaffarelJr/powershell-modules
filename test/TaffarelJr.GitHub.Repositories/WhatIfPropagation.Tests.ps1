#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$folder = Join-Path ([IO.Path]::GetTempPath()) "keys-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$key = Join-Path $folder 'id_ed25519.pub'
Set-Content -LiteralPath $key -Value 'ssh-ed25519 AAAA'

$cases = @(
    @{ Name = 'Add-GitHubDeployKey'; Call = { Add-GitHubDeployKey -KeyFile $key -Repository 'o/r' } }
    @{ Name = 'Copy-GitHubLabel'; Call = { Copy-GitHubLabel -Source 'a/b' -Repository 'o/r' } }
    @{ Name = 'New-GitHubFork'; Call = { New-GitHubFork -Repository 'o/r' } }
    @{ Name = 'New-GitHubLabel'; Call = { New-GitHubLabel -Name 'bug' -Repository 'o/r' } }
    @{ Name = 'New-GitHubRepository'; Call = { New-GitHubRepository -Name 'o/new' -Visibility private } }
    @{ Name = 'Remove-GitHubDeployKey'; Call = { Remove-GitHubDeployKey -Id 42 -Repository 'o/r' } }
    @{ Name = 'Remove-GitHubLabel'; Call = { Remove-GitHubLabel -Name 'bug' -Repository 'o/r' } }
    @{ Name = 'Remove-GitHubRepository'; Call = { Remove-GitHubRepository -Repository 'o/r' } }
    @{ Name = 'Remove-GitHubSecret'; Call = { Remove-GitHubSecret -Name 'OLD' -Repository 'o/r' } }
    @{ Name = 'Remove-GitHubVariable'; Call = { Remove-GitHubVariable -Name 'OLD' -Repository 'o/r' } }
    @{ Name = 'Rename-GitHubRepository'; Call = { Rename-GitHubRepository -Repository 'o/r' -NewName 'renamed' } }
    @{ Name = 'Set-GitHubDefaultRepository'; Call = { Set-GitHubDefaultRepository -Repository 'o/r' } }
    @{ Name = 'Set-GitHubLabel'; Call = { Set-GitHubLabel -Name 'bug' -Color 'FF0000' -Repository 'o/r' } }
    @{ Name = 'Set-GitHubRepository'; Call = { Set-GitHubRepository -Repository 'o/r' -Description 'd' } }
    @{ Name = 'Set-GitHubSecret'; Call = { Set-GitHubSecret -Name 'S' -Value 'SENTINEL_VALUE' -Repository 'o/r' } }
    @{ Name = 'Set-GitHubVariable'; Call = { Set-GitHubVariable -Name 'V' -Value 'x' -Repository 'o/r' } }
    @{ Name = 'Sync-GitHubRepository'; Call = { Sync-GitHubRepository -Destination 'me/fork' -Source 'o/r' } }
)

try {
    foreach ($case in $cases) {
        #───────────────────────────────────────────────────────────────────────
        # Arrange - a function run with -WhatIf, calling the command that changes things
        $fake = New-FakeGitHubCli
        try {
            # Act
            $whatIf = Get-WhatIfOutput -ScriptBlock { Invoke-WhatIfCaller -Call $case.Call -WhatIf }
            $calls = @(Get-FakeGitHubCall -Fixture $fake)

            # Assert
            Assert-Equal -Expected 1 -Actual $whatIf.Messages.Count `
                -Message "$($case.Name) reaches its guard under its caller's -WhatIf, and says what it would do"
            Assert-Equal -Expected 0 -Actual $calls.Count -Message 'and changes nothing: gh is never called'
        }
        finally {
            Remove-FakeGitHubCli -Fixture $fake
        }
    }
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
