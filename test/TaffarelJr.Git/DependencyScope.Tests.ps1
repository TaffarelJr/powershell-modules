#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A call into a module that is only in RequiredModules is resolved through the
# global scope, so a function of the same name defined there after the imports
# would take the call. The module imports what it requires into its own scope.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestRepo
$calls = [System.Collections.Generic.List[string]]::new()
$shadowed = 'Invoke-NativeCommand', 'Invoke-NativeRead', 'Hide-UrlCredential'
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function of the same name as each command the module calls in
    # ProcessInvocation, defined in the global scope after both modules loaded
    foreach ($name in $shadowed) {
        $recording = { $calls.Add($name) }.GetNewClosure()
        Set-Item -LiteralPath "Function:\global:$name" -Value $recording
    }

    # Act
    $branch = Get-GitBranch -RepoPath $repo
    $branches = @(Get-GitBranch -List -RepoPath $repo)
    $run = Get-WhatIfOutput { Set-GitRemote -Name 'origin' -Url 'https://example.com/x.git' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected 'main' -Actual $branch `
        -Message 'A read that goes through Invoke-NativeRead gets git''s real answer'
    Assert-Equal -Expected @('main') -Actual $branches -Message 'and so does one that goes through Invoke-NativeCommand'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message 'and a call that hides a URL''s credential runs'
    Assert-Equal -Expected @() -Actual @($calls) `
        -Message 'while none of the global functions of those names, defined after the imports, was ever called'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a session where the module it requires is not loaded
    Remove-Module -Name 'TaffarelJr.Git', 'TaffarelJr.ProcessInvocation' -Force

    # Act / Assert
    Assert-Throws -ScriptBlock { Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psm1') -Force } `
        -MessageLike '*TaffarelJr.ProcessInvocation must be loaded before TaffarelJr.Git.' `
        -Message 'The root module refuses to load without the module it requires, and says which'
}
finally {
    foreach ($name in $shadowed) {
        Remove-Item -LiteralPath "Function:\$name" -ErrorAction SilentlyContinue
    }

    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
