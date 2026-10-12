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
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$global:ShadowCalls = [System.Collections.Generic.List[string]]::new()

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a function of the same name as one this module calls in Core, defined in the global scope
# after the modules were imported, as another module loaded later could define it
function global:Invoke-GitHubCommand {
    $global:ShadowCalls.Add('Invoke-GitHubCommand')
    return @('from the shadow')
}

$fake = New-FakeGitHubCli -Output @('gho_fromgh')
try {
    # Act
    $token = Get-GitHubToken
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ShadowCalls) `
        -Message 'A later function of the same name in the global scope is never called by the module'
    Assert-Equal -Expected 'gho_fromgh' -Actual $token -Message 'The module runs Core''s own command'
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'which reaches gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same for a Core function that a parameter's validation calls
function global:Assert-GitHubHostname {
    $global:ShadowCalls.Add('Assert-GitHubHostname')
    throw 'The shadow refuses every host.'
}

$fake = New-FakeGitHubCli -Output @('gho_fromgh')
try {
    # Act
    $token = Get-GitHubToken -Hostname 'ghe.example.com'

    # Assert
    Assert-Equal -Expected 'gho_fromgh' -Actual $token -Message 'Validation uses Core''s own check of the host name'
    Assert-Equal -Expected @() -Actual @($global:ShadowCalls) -Message 'and never the shadow'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same for a ProcessInvocation function the module calls when it refuses an account name
function global:Hide-UrlCredential {
    $global:ShadowCalls.Add('Hide-UrlCredential')
    return 'from the shadow'
}

# Act
$failure = $null
try {
    Disconnect-GitHubAccount -User 'two words'
}
catch {
    $failure = $_
}

# Assert
Assert-That -Condition ($failure.Exception.Message -like "*'two words' is not an account name*") `
    -Message 'The refusal names the value as ProcessInvocation''s own command shows it'
Assert-Equal -Expected @() -Actual @($global:ShadowCalls) -Message 'and the shadow is never called'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the module's script imported with Core not loaded, as a manifest-less import would find it
Remove-Module -Name 'TaffarelJr.GitHub.Core' -Force
$script = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psm1'

# Act / Assert
Assert-Throws -ScriptBlock {
    Import-Module $script -Force
} -MessageLike '*TaffarelJr.GitHub.Core must be loaded before TaffarelJr.GitHub.Account.*' `
    -Message 'A module it requires that is not loaded is named, rather than found through the global scope'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - Core loaded again, and ProcessInvocation, the other module it requires, not loaded
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Remove-Module -Name 'TaffarelJr.ProcessInvocation' -Force

# Act / Assert
Assert-Throws -ScriptBlock {
    Import-Module $script -Force
} -MessageLike '*TaffarelJr.ProcessInvocation must be loaded before TaffarelJr.GitHub.Account.*' `
    -Message 'and so is each one of them'

exit (Complete-TestRun)
