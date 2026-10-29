#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$object = 'System.Management.Automation.PSObject'
$text = 'System.String'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every function that returns something, with the answer gh would give it
$returning = @(
    @{ Name = 'Get-GitHubDefaultRepository'; Call = { Get-GitHubDefaultRepository }; Output = 'o/r'; Type = $text }
    @{
        Name   = 'Get-GitHubDeployKey'
        Call   = { Get-GitHubDeployKey -Repository 'o/r' }
        Output = '[{"id":1,"title":"CI"}]'
        Type   = $object
    }
    @{
        Name   = 'Get-GitHubLabel'
        Call   = { Get-GitHubLabel -Repository 'o/r' }
        Output = '[{"name":"bug"}]'
        Type   = $object
    }
    @{
        Name   = 'Get-GitHubRepository'
        Call   = { Get-GitHubRepository -Repository 'o/r' }
        Output = '{"name":"r"}'
        Type   = $object
    }
    @{
        Name   = 'Get-GitHubRepository'
        Call   = { Get-GitHubRepository -List -Owner 'o' }
        Output = '[{"name":"r"}]'
        Type   = $object
    }
    @{
        Name   = 'Get-GitHubRuleset'
        Call   = { Get-GitHubRuleset -Id 1 -Repository 'o/r' }
        Output = '{"id":1,"name":"Main"}'
        Type   = $object
    }
    @{
        Name   = 'Get-GitHubRuleset'
        Call   = { Get-GitHubRuleset -List -Repository 'o/r' }
        Output = '[[{"id":1,"name":"Main"}]]'
        Type   = $object
    }
    @{
        Name   = 'Get-GitHubRulesetCheck'
        Call   = { Get-GitHubRulesetCheck -Branch 'main' -Repository 'o/r' }
        Output = '[[{"type":"deletion","ruleset_id":1}]]'
        Type   = $object
    }
    @{
        Name   = 'Get-GitHubSecret'
        Call   = { Get-GitHubSecret -Repository 'o/r' }
        Output = '[{"name":"S"}]'
        Type   = $object
    }
    @{
        Name   = 'Get-GitHubVariable'
        Call   = { Get-GitHubVariable -Repository 'o/r' }
        Output = '[{"name":"V","value":"1"}]'
        Type   = $object
    }
    @{
        Name   = 'New-GitHubFork'
        Call   = { New-GitHubFork -Repository 'o/r' }
        Output = 'https://github.com/me/r'
        Type   = $text
    }
    @{
        Name   = 'New-GitHubRepository'
        Call   = { New-GitHubRepository -Name 'r' -Visibility private }
        Output = 'https://github.com/o/r'
        Type   = $text
    }
)

# Act / Assert
foreach ($row in $returning) {
    $fake = New-FakeGitHubCli -Output @($row.Output)
    try {
        $result = @(& $row.Call)
        $declared = @((Get-Command $row.Name).OutputType | ForEach-Object { $_.Type.FullName })

        Assert-Equal -Expected @($row.Type) -Actual $declared `
            -Message "$($row.Name) declares the type it returns"
        Assert-That -Condition ($result.Count -eq 1 -and $result[0] -is [type]$row.Type) `
            -Message "$($row.Name) really returns one $($row.Type) for $($row.Output)"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every function that returns nothing
$silent = @(
    'Add-GitHubDeployKey'
    'Copy-GitHubLabel'
    'New-GitHubLabel'
    'Remove-GitHubDeployKey'
    'Remove-GitHubLabel'
    'Remove-GitHubRepository'
    'Remove-GitHubSecret'
    'Remove-GitHubVariable'
    'Rename-GitHubRepository'
    'Set-GitHubDefaultRepository'
    'Set-GitHubLabel'
    'Set-GitHubRepository'
    'Set-GitHubSecret'
    'Set-GitHubVariable'
    'Sync-GitHubRepository'
)

# Act / Assert
foreach ($name in $silent) {
    Assert-Equal -Expected @() -Actual @((Get-Command $name).OutputType) -Message "$name declares no output type"
}

exit (Complete-TestRun)
