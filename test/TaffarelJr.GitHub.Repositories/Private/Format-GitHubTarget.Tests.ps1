#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') `
    -Force `
    -PassThru

$format = {
    param([hashtable]$Arguments)

    Format-GitHubTarget @Arguments
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every place a change can be made, with and without an item in it
$rows = @(
    @{
        Arguments = @{ Repository = 'o/r' }
        Expected  = 'o/r'
        Message   = 'A named repository is shown as OWNER/REPO'
    }
    @{
        Arguments = @{ Repository = 'https://user:SENTINEL@github.com/o/r'; Item = 'label bug' }
        Expected  = 'o/r label bug'
        Message   = 'A URL is shown by its name, without the credential it carried'
    }
    @{
        Arguments = @{ Repository = 'www.github.com/o/r' }
        Expected  = 'o/r'
        Message   = 'www.github.com is github.com'
    }
    @{
        Arguments = @{ Repository = [PSCustomObject]@{ Url = 'https://ghe.example.com/o/r.git' } }
        Expected  = 'ghe.example.com/o/r'
        Message   = 'A repository object is named by its Url, keeping a host other than github.com'
    }
    @{
        Arguments = @{ Repository = '' }
        Expected  = "the current directory's repository"
        Message   = 'An empty one is the current directory''s, said in words'
    }
    @{
        Arguments = @{}
        Expected  = "the current directory's repository"
        Message   = 'as is one left out'
    }
    @{
        Arguments = @{ Repository = 'o/r'; Item = 'label bug' }
        Expected  = 'o/r label bug'
        Message   = 'An item follows its repository'
    }
    @{
        Arguments = @{ Repository = 'o/r'; Environment = 'prod'; Item = 'secret A' }
        Expected  = 'o/r environment prod secret A'
        Message   = 'An environment follows its repository'
    }
    @{
        Arguments = @{ Environment = 'prod'; Item = 'variable A' }
        Expected  = 'environment prod variable A'
        Message   = 'and stands alone in the current directory''s, left unnamed'
    }
    @{
        Arguments = @{ Item = 'label bug' }
        Expected  = 'label bug'
        Message   = 'as does an item'
    }
    @{
        Arguments = @{ Application = 'Actions' }
        Expected  = "the current directory's repository actions"
        Message   = 'An application with no item still names the current directory''s repository'
    }
    @{
        Arguments = @{ Organization = 'org'; Application = 'Dependabot'; Item = 'secret A' }
        Expected  = 'organization org dependabot secret A'
        Message   = 'An organization replaces the repository, and the application is lower-cased before the item'
    }
    @{
        Arguments = @{ User = $true; Application = 'codespaces'; Item = 'secret A' }
        Expected  = 'the current user codespaces secret A'
        Message   = 'The user replaces the repository too'
    }
    @{
        Arguments = @{ Repository = 'o/r'; Environment = 'user:SENTINEL@h'; Item = 'secret A' }
        Expected  = 'o/r environment ***@h secret A'
        Message   = 'An environment holding a credential is shown without it'
    }
    @{
        Arguments = @{ Repository = $null; User = $false; Organization = ''; Environment = ''; Application = '' }
        Expected  = "the current directory's repository"
        Message   = 'Empty and $false scope values, as a resolved scope holds them, name nothing'
    }
)

# Act / Assert
foreach ($row in $rows) {
    Assert-Equal -Expected $row.Expected -Actual (& $module $format $row.Arguments) -Message $row.Message
}

exit (Complete-TestRun)
