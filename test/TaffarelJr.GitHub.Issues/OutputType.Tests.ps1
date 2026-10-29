#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each command that returns objects, called through the fake gh: what it really returns is what its
# [OutputType()] names
$issue = '{"number":7,"url":"https://github.com/o/r/issues/7","title":"t"}'
$created = 'https://github.com/o/r/issues/9'
$returning = @(
    @{
        Command  = 'Get-GitHubIssue'
        Answer   = $issue
        Block    = { Get-GitHubIssue -Issue 7 -Repository 'o/r' }
        Declared = [PSCustomObject]
        Runtime  = 'System.Management.Automation.PSCustomObject'
        Name     = 'Get-GitHubIssue, for one issue'
    }
    @{
        Command  = 'Get-GitHubIssue'
        Answer   = "[$issue]"
        Block    = { Get-GitHubIssue -List -Repository 'o/r' }
        Declared = [PSCustomObject]
        Runtime  = 'System.Management.Automation.PSCustomObject'
        Name     = 'Get-GitHubIssue, for a listing'
    }
    @{
        Command  = 'Get-GitHubIssueStatus'
        Answer   = $issue
        Block    = { Get-GitHubIssueStatus -Repository 'o/r' }
        Declared = [PSCustomObject]
        Runtime  = 'System.Management.Automation.PSCustomObject'
        Name     = 'Get-GitHubIssueStatus'
    }
    @{
        Command  = 'New-GitHubIssue'
        Answer   = $created
        Block    = { New-GitHubIssue -Title 't' -Body 'b' -Repository 'o/r' }
        Declared = [string]
        Runtime  = 'System.String'
        Name     = 'New-GitHubIssue'
    }
)
foreach ($case in $returning) {
    $fake = New-FakeGitHubCli -Output $case.Answer
    try {
        # Act
        $result = @(& $case.Block)
        $declared = @((Get-Command -Name $case.Command).OutputType.Type)

        # Assert
        Assert-Equal -Expected 1 -Actual $result.Count -Message "$($case.Name) returns one object"
        Assert-Equal -Expected $case.Runtime -Actual $result[0].GetType().FullName `
            -Message "$($case.Name) returns a $($case.Runtime)"
        Assert-That -Condition ($case.Declared -in $declared) `
            -Message "$($case.Name) declares [OutputType($($case.Declared.Name))]"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each command that returns nothing, called through a fake gh that prints a URL, as gh does
$silent = @(
    @{ Command = 'Add-GitHubIssueComment'; Block = { Add-GitHubIssueComment -Issue 1 -Body 'x' -Repository 'o/r' } }
    @{ Command = 'Close-GitHubIssue'; Block = { Close-GitHubIssue -Issue 1 -Repository 'o/r' } }
    @{ Command = 'Lock-GitHubIssue'; Block = { Lock-GitHubIssue -Issue 1 -Repository 'o/r' } }
    @{ Command = 'Move-GitHubIssue'; Block = { Move-GitHubIssue 1 'o/x' -Repository 'o/r' } }
    @{ Command = 'Open-GitHubIssue'; Block = { Open-GitHubIssue -Issue 1 -Repository 'o/r' } }
    @{ Command = 'Remove-GitHubIssue'; Block = { Remove-GitHubIssue -Issue 1 -Repository 'o/r' } }
    @{ Command = 'Set-GitHubIssue'; Block = { Set-GitHubIssue -Issue 1 -Title 'x' -Pinned -Repository 'o/r' } }
    @{ Command = 'Unlock-GitHubIssue'; Block = { Unlock-GitHubIssue -Issue 1 -Repository 'o/r' } }
)
foreach ($case in $silent) {
    $fake = New-FakeGitHubCli -Output $created
    try {
        # Act
        $result = @(& $case.Block)
        $declared = @((Get-Command -Name $case.Command).OutputType)

        # Assert
        Assert-Equal -Expected 0 -Actual $result.Count -Message "$($case.Command) returns nothing"
        Assert-Equal -Expected 0 -Actual $declared.Count -Message "$($case.Command) declares no [OutputType()]"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

exit (Complete-TestRun)
