#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'A function shadowing a command runs in the global scope, where only a global variable is seen.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$env:GH_HOST = $null
$global:ShadowCalls = [System.Collections.Generic.List[string]]::new()

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a function of the same name as one this module calls in Core, defined in the global scope
# after the modules were imported, as another module loaded later could define it
function global:Invoke-GitHubCommand {
    $global:ShadowCalls.Add('Invoke-GitHubCommand')
    return @('[{"path":"from the shadow"}]')
}

$fake = New-FakeGitHubCli -Output @('[{"path":"from gh"}]')
try {
    # Act
    $found = @(Find-GitHubCode -Query 'x')
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ShadowCalls) `
        -Message 'A later function of the same name in the global scope is never called by the module'
    Assert-Equal -Expected 'from gh' -Actual $found[0].Path -Message 'The module runs Core''s own command'
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'which reaches gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same for a Core function that reads a repository, and a ProcessInvocation function that hides
# the credential in it
function global:ConvertTo-GitHubRepositoryReference {
    $global:ShadowCalls.Add('ConvertTo-GitHubRepositoryReference')
    return 'from/shadow'
}
function global:Hide-UrlCredential {
    $global:ShadowCalls.Add('Hide-UrlCredential')
    return 'from the shadow'
}

$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubCode -Repository 'o/r' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('--repo', 'o/r') -Actual @($call.Arguments[4, 5]) `
        -Message 'The repository is read by Core''s own command'
    Assert-Equal -Expected @() -Actual @($global:ShadowCalls) -Message 'and the shadows are never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the module's script imported with Core not loaded, as a manifest-less import would find it
Remove-Module -Name 'TaffarelJr.GitHub.Core' -Force
$script = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psm1'

# Act / Assert
Assert-Throws -ScriptBlock {
    Import-Module $script -Force
} -MessageLike '*TaffarelJr.GitHub.Core must be loaded before TaffarelJr.GitHub.Search.*' `
    -Message 'A module it requires that is not loaded is named, rather than found through the global scope'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - Core loaded again, and ProcessInvocation, the other module it requires, not loaded
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Remove-Module -Name 'TaffarelJr.ProcessInvocation' -Force

# Act / Assert
Assert-Throws -ScriptBlock {
    Import-Module $script -Force
} -MessageLike '*TaffarelJr.ProcessInvocation must be loaded before TaffarelJr.GitHub.Search.*' `
    -Message 'and so is each one of them'

exit (Complete-TestRun)
