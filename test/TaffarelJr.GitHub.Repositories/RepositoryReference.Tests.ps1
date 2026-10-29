#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

# Every function that takes a repository as its operand, with the parameter
# that names it and what it needs besides. Each puts the repository straight
# after its subcommand.
$operandFunctions = @(
    @{ Name = 'Get-GitHubRepository'; Parameter = 'Repository'; Extra = @{} }
    @{ Name = 'New-GitHubFork'; Parameter = 'Repository'; Extra = @{} }
    @{ Name = 'Remove-GitHubRepository'; Parameter = 'Repository'; Extra = @{} }
    @{ Name = 'Set-GitHubRepository'; Parameter = 'Repository'; Extra = @{ Description = 'd' } }
    @{ Name = 'Sync-GitHubRepository'; Parameter = 'Destination'; Extra = @{} }
)

$keyFolder = Join-Path ([IO.Path]::GetTempPath()) "repository-reference-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $keyFolder | Out-Null
$keyFile = Join-Path $keyFolder 'id.pub'
Set-Content -LiteralPath $keyFile -Value 'ssh-ed25519 AAAA'

# Every function that names its repository through gh's --repo, with what it
# needs besides.
$repoFlagFunctions = @(
    @{ Name = 'Get-GitHubLabel'; Parameter = 'Repository'; Extra = @{} }
    @{ Name = 'New-GitHubLabel'; Parameter = 'Repository'; Extra = @{ Name = 'bug' } }
    @{ Name = 'Set-GitHubLabel'; Parameter = 'Repository'; Extra = @{ Name = 'bug'; Color = '000000' } }
    @{ Name = 'Remove-GitHubLabel'; Parameter = 'Repository'; Extra = @{ Name = 'bug' } }
    @{ Name = 'Copy-GitHubLabel'; Parameter = 'Repository'; Extra = @{ Source = 'cli/cli' } }
    @{ Name = 'Get-GitHubSecret'; Parameter = 'Repository'; Extra = @{} }
    @{ Name = 'Set-GitHubSecret'; Parameter = 'Repository'; Extra = @{ Name = 'KEY'; Value = 'v' } }
    @{ Name = 'Remove-GitHubSecret'; Parameter = 'Repository'; Extra = @{ Name = 'KEY' } }
    @{ Name = 'Get-GitHubVariable'; Parameter = 'Repository'; Extra = @{} }
    @{ Name = 'Set-GitHubVariable'; Parameter = 'Repository'; Extra = @{ Name = 'V'; Value = 'v' } }
    @{ Name = 'Remove-GitHubVariable'; Parameter = 'Repository'; Extra = @{ Name = 'V' } }
    @{ Name = 'Add-GitHubDeployKey'; Parameter = 'Repository'; Extra = @{ KeyFile = $keyFile } }
    @{ Name = 'Get-GitHubDeployKey'; Parameter = 'Repository'; Extra = @{} }
    @{ Name = 'Remove-GitHubDeployKey'; Parameter = 'Repository'; Extra = @{ Id = 1 } }
    @{ Name = 'Rename-GitHubRepository'; Parameter = 'Repository'; Extra = @{ NewName = 'renamed' } }
)

function Get-RepositoryReferenceCall {
    param($Function, $Repository, [switch]$Piped)

    $fake = New-FakeGitHubCli -Output @('[]')
    try {
        $extra = $Function.Extra
        if ($Piped) {
            $Repository | & $Function.Name @extra | Out-Null
        }
        else {
            $named = @{ $Function.Parameter = $Repository }
            & $Function.Name @named @extra | Out-Null
        }

        return @(Get-FakeGitHubCall -Fixture $fake)
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

$enterprise = [PSCustomObject]@{ NameWithOwner = 'o/viewed'; Url = 'https://ghe.example.com/o/viewed'; Name = 'viewed' }
$found = [PSCustomObject]@{ FullName = 'o/found' }
$listed = [PSCustomObject]@{ NameWithOwner = 'o/listed'; Visibility = 'PUBLIC' }

try {
    foreach ($function in $operandFunctions) {
        #───────────────────────────────────────────────────────────────────────
        # Act - repository objects piped in, as a listing or a search returns them
        $calls = Get-RepositoryReferenceCall -Function $function -Repository @($enterprise, $found, $listed) -Piped

        # Assert
        Assert-Equal -Expected 3 -Actual $calls.Count `
            -Message "$($function.Name): each piped repository object is acted on in its own call"
        Assert-Equal -Expected 'https://ghe.example.com/o/viewed' -Actual $calls[0].Arguments[2] `
            -Message "$($function.Name): an object is read by its Url first, so an enterprise repository keeps its host"
        Assert-Equal -Expected 'o/found' -Actual $calls[1].Arguments[2] `
            -Message "$($function.Name): a search result without a Url is read by its FullName"
        Assert-Equal -Expected 'o/listed' -Actual $calls[2].Arguments[2] `
            -Message "$($function.Name): a listing without a Url by its NameWithOwner, never by the text of the object"

        #───────────────────────────────────────────────────────────────────────
        # Act - a name and a URL given as the argument
        $byName = Get-RepositoryReferenceCall -Function $function -Repository 'o/named'
        $byUrl = Get-RepositoryReferenceCall -Function $function -Repository 'https://github.com/o/linked'

        # Assert
        Assert-Equal -Expected 'o/named' -Actual $byName[0].Arguments[2] `
            -Message "$($function.Name): OWNER/REPO is passed to gh as it is"
        Assert-Equal -Expected 'https://github.com/o/linked' -Actual $byUrl[0].Arguments[2] `
            -Message "$($function.Name): a URL is passed to gh as it is"
    }

    foreach ($function in $repoFlagFunctions) {
        #───────────────────────────────────────────────────────────────────────
        # Act - a repository object, as a listing returns it, and a name
        $byObject = Get-RepositoryReferenceCall -Function $function -Repository $enterprise
        $byName = Get-RepositoryReferenceCall -Function $function -Repository 'o/named'
        $objectFlag = [array]::IndexOf($byObject[0].Arguments, '--repo')
        $nameFlag = [array]::IndexOf($byName[0].Arguments, '--repo')

        # Assert
        Assert-Equal -Expected 'https://ghe.example.com/o/viewed' -Actual $byObject[0].Arguments[$objectFlag + 1] `
            -Message "$($function.Name): a repository object goes to --repo by its Url, not as the text of the object"
        Assert-Equal -Expected 'o/named' -Actual $byName[0].Arguments[$nameFlag + 1] `
            -Message "$($function.Name): OWNER/REPO goes to --repo as it is"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a repository that is a gh option, and one given as $null, for each function in turn
    $fake = New-FakeGitHubCli
    try {
        foreach ($function in @($operandFunctions) + @($repoFlagFunctions)) {
            $extra = $function.Extra
            $option = @{ $function.Parameter = '--web' }

            # Act / Assert
            Assert-Throws -ScriptBlock {
                & $function.Name @option @extra
            } -MessageLike "*'--web' is not a repository*" `
                -Message "$($function.Name): a repository that is a gh option is refused"
        }

        $nullable = @($operandFunctions | Where-Object Name -NE 'Remove-GitHubRepository') + @($repoFlagFunctions | Where-Object Name -NE 'Rename-GitHubRepository')
        foreach ($function in $nullable) {
            $extra = $function.Extra
            $missing = @{ $function.Parameter = $null }

            # Act / Assert
            Assert-Throws -ScriptBlock {
                & $function.Name @missing @extra
            } -MessageLike "-$($function.Parameter) was given, but it is `$null*" `
                -Message "$($function.Name): a repository given as `$null throws instead of meaning the current directory's"
        }

        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
            -Message 'and gh is called for none of them'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}
finally {
    Remove-Item -LiteralPath $keyFolder -Recurse -Force
}

exit (Complete-TestRun)
