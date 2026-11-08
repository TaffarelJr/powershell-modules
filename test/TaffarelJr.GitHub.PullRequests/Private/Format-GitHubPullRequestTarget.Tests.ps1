#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') `
    -Force `
    -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each kind of operand, with and without a repository
$current = "the current branch's pull request"
$rows = @(
    @{
        Target     = [PSCustomObject]@{ Arguments = [string[]]@('12'); Name = 'pull request 12' }
        Repository = ''
        Expected   = 'pull request #12'
        Message    = 'A number reads as #12'
    }
    @{
        Target     = [PSCustomObject]@{ Arguments = [string[]]@('12'); Name = 'pull request 12' }
        Repository = 'o/r'
        Expected   = 'o/r pull request #12'
        Message    = 'with the repository ahead of it when one was given'
    }
    @{
        Target     = [PSCustomObject]@{ Arguments = [string[]]@('feature/x'); Name = 'pull request feature/x' }
        Repository = 'o/r'
        Expected   = 'o/r pull request feature/x'
        Message    = 'A branch name reads as it is'
    }
    @{
        Target     = [PSCustomObject]@{ Arguments = [string[]]@('feature/x'); Name = 'pull request feature/x' }
        Repository = ''
        Expected   = 'pull request feature/x'
        Message    = 'with no repository too'
    }
    @{
        Target     = [PSCustomObject]@{
            Arguments = [string[]]@('https://github.com/a/b/pull/3')
            Name      = 'pull request https://github.com/a/b/pull/3'
        }
        Repository = ''
        Expected   = 'a/b pull request #3'
        Message    = 'A github.com URL names its own repository, without the host'
    }
    @{
        Target     = [PSCustomObject]@{
            Arguments = [string[]]@('https://github.com/a/b/pull/3/files#r1')
            Name      = 'pull request https://github.com/a/b/pull/3/files#r1'
        }
        Repository = 'x/y'
        Expected   = 'a/b pull request #3'
        Message    = 'whatever follows the number, and whatever -Repository says'
    }
    @{
        Target     = [PSCustomObject]@{
            Arguments = [string[]]@('https://ghe.example.com/a/b/pull/3')
            Name      = 'pull request https://ghe.example.com/a/b/pull/3'
        }
        Repository = 'ghe.example.com/a/b'
        Expected   = 'ghe.example.com/a/b pull request #3'
        Message    = 'and an Enterprise URL with its host'
    }
    @{
        Target     = [PSCustomObject]@{ Arguments = [string[]]@(); Name = $current }
        Repository = 'o/r'
        Expected   = "the current branch's pull request in o/r"
        Message    = 'The current branch''s pull request says which repository it is looked for in'
    }
    @{
        Target     = [PSCustomObject]@{ Arguments = [string[]]@(); Name = $current }
        Repository = ''
        Expected   = "the current branch's pull request"
        Message    = 'and reads plainly without one'
    }
    @{
        Target     = [PSCustomObject]@{ Arguments = [string[]]@('12'); Name = 'pull request 12' }
        Repository = 'https://www.github.com/o/r.git'
        Expected   = 'o/r pull request #12'
        Message    = 'A -Repository URL reads as OWNER/REPO, as a pull request URL does'
    }
    @{
        Target     = [PSCustomObject]@{ Arguments = [string[]]@('12'); Name = 'pull request 12' }
        Repository = 'https://user:SENTINEL@github.com/o/r'
        Expected   = 'o/r pull request #12'
        Message    = 'A credential in -Repository is left out'
    }
    @{
        Target     = [PSCustomObject]@{ Arguments = [string[]]@(); Name = $current }
        Repository = 'https://user:SENTINEL@github.com/o/r'
        Expected   = "the current branch's pull request in o/r"
        Message    = 'also for the current branch''s pull request'
    }
    @{
        Target     = [PSCustomObject]@{
            Arguments = [string[]]@('https://user:SENTINEL@ghe.example.com/a/b/pull/3')
            Name      = 'pull request https://user:SENTINEL@ghe.example.com/a/b/pull/3'
        }
        Repository = ''
        Expected   = 'ghe.example.com/a/b pull request #3'
        Message    = 'and in a pull request URL'
    }
)

# Act / Assert
foreach ($row in $rows) {
    $format = { Format-GitHubPullRequestTarget -Target $args[0] -Repository $args[1] }
    $actual = & $module $format $row.Target $row.Repository
    Assert-Equal -Expected $row.Expected -Actual $actual -Message $row.Message
}

exit (Complete-TestRun)
