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
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$global:ShadowCalls = [System.Collections.Generic.List[string]]::new()

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a function of the same name as one Core calls in ProcessInvocation, defined in the global scope
# after both modules were imported, as another module loaded later could define it
function global:Invoke-NativeRead {
    $global:ShadowCalls.Add('Invoke-NativeRead')
    return @{ Started = $true; Ok = $true; ExitCode = 0; Output = @('from the shadow'); ErrorOutput = @() }
}

$fake = New-FakeGitHubCli -Output @('from gh')
try {
    # Act
    $lines = @(Invoke-GitHubCommand -Activity 'Reading' -Argument @('api', 'user'))
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ShadowCalls) `
        -Message 'A later function of the same name in the global scope is never called by Core'
    Assert-Equal -Expected @('from gh') -Actual $lines -Message 'Core runs ProcessInvocation''s own command'
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'which reaches gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - Core imported again, with the shadow still in the global scope
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$fake = New-FakeGitHubCli -Output @('from gh')
try {
    # Act
    $lines = @(Invoke-GitHubCommand -Activity 'Reading' -Argument @('api', 'user'))

    # Assert
    Assert-Equal -Expected @() -Actual @($global:ShadowCalls) -Message 'Importing Core again keeps the shadow out'
    Assert-Equal -Expected @('from gh') -Actual $lines -Message 'and the real command answers'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same through a function that reaches ProcessInvocation by a longer way
function global:Hide-UrlCredential {
    $global:ShadowCalls.Add('Hide-UrlCredential')
    return 'from the shadow'
}

# Act
$name = Format-GitHubRepositoryName -Repository 'https://x-access-token:SECRET@github.com/o/r'

# Assert
Assert-Equal -Expected 'o/r' -Actual $name -Message 'A shadow of Hide-UrlCredential does not change what a name shows'
Assert-Equal -Expected @() -Actual @($global:ShadowCalls) -Message 'and is never called'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the module's script imported with ProcessInvocation not loaded, as a manifest-less import would find it
Remove-Module -Name 'TaffarelJr.ProcessInvocation' -Force
$script = Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psm1'

# Act / Assert
Assert-Throws -ScriptBlock {
    Import-Module $script -Force
} -MessageLike '*TaffarelJr.ProcessInvocation must be loaded before TaffarelJr.GitHub.Core.*' `
    -Message 'A module it requires that is not loaded is named, rather than found through the global scope'

exit (Complete-TestRun)
