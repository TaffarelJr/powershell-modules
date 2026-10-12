#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot 'GitHubGistsTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each command that returns objects, called through the fake gh: what it really returns is what its
# [OutputType()] names. The fake clones nothing, so the folder a clone would create is made here.
$gist = '{"id":"abc123","html_url":"https://gist.github.com/me/abc123","files":{}}'
$folder = New-GistTestFolder
$returning = @(
    @{
        Command  = 'Get-GitHubGist'
        Answer   = $gist
        Block    = { Get-GitHubGist -Id 'abc123' }
        Declared = [PSCustomObject]
        Runtime  = 'System.Management.Automation.PSCustomObject'
        Name     = 'Get-GitHubGist, for one gist'
    }
    @{
        Command  = 'Get-GitHubGist'
        Answer   = "[[$gist]]"
        Block    = { Get-GitHubGist -List }
        Declared = [PSCustomObject]
        Runtime  = 'System.Management.Automation.PSCustomObject'
        Name     = 'Get-GitHubGist, for a listing'
    }
    @{
        Command  = 'New-GitHubGist'
        Answer   = $gist
        Block    = { New-GitHubGist -Content 'x' -FileName 'a.txt' }
        Declared = [string]
        Runtime  = 'System.String'
        Name     = 'New-GitHubGist'
    }
    @{
        Command  = 'Copy-GitHubGist'
        Answer   = ''
        Block    = { Copy-GitHubGist -Id 'abc123' -Destination $folder }
        Declared = [System.IO.DirectoryInfo]
        Runtime  = 'System.IO.DirectoryInfo'
        Name     = 'Copy-GitHubGist'
    }
)
try {
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
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each command that returns nothing, called through a fake gh that prints a line, as gh does
$silent = @(
    @{ Command = 'Remove-GitHubGist'; Block = { Remove-GitHubGist -Id 'abc123' } }
    @{ Command = 'Rename-GitHubGistFile'; Block = { Rename-GitHubGistFile -Id 'abc123' -OldName 'a' -NewName 'b' } }
    @{ Command = 'Set-GitHubGist'; Block = { Set-GitHubGist -Id 'abc123' -RemoveFile 'a.txt' } }
    @{ Command = 'Set-GitHubGist'; Block = { Set-GitHubGist -Id 'abc123' -Description 'd' } }
)
foreach ($case in $silent) {
    $fake = New-FakeGitHubCli -Output 'done'
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
