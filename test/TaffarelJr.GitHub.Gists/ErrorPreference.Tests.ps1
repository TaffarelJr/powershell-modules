#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Read by the script blocks the tables hand to Get-WhatIfOutput, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot 'GitHubGistsTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a cmdlet that fails without throwing, in a function with a begin block and in one with no named
# block. A caller's -ErrorAction SilentlyContinue or Ignore would become the function's own preference and hide
# it, so the function sets its own to Stop. The fake clones nothing, so Get-Item finds no folder.
$folder = New-GistTestFolder
$missing = Join-Path $folder 'not-cloned'
Use-ReplacedFunction -Module $module -Name 'Assert-GitHubGistText' -Body { Write-Error 'the text failed' }
$cases = @(
    @{
        Block   = { Copy-GitHubGist -Id 'abc123' -Destination $missing -ErrorAction $preference }
        Calls   = 1
        Failure = "Cannot find path '$missing' because it does not exist."
        Name    = 'a failure in a process block, in a function that sets its preference in its begin block'
    }
    @{
        Block   = { New-GitHubGist -Content 'x' -FileName 'a.txt' -ErrorAction $preference }
        Calls   = 0
        Failure = 'the text failed'
        Name    = 'a failure in a function with no named block'
    }
)
try {
    foreach ($case in $cases) {
        foreach ($preference in 'SilentlyContinue', 'Ignore') {
            $fake = New-FakeGitHubCli
            try {
                # Act
                $run = Get-WhatIfOutput -CaptureError -ScriptBlock $case.Block
                $calls = @(Get-FakeGitHubCall -Fixture $fake)

                # Assert
                $because = "$($case.Name), under -ErrorAction $preference"
                Assert-Equal -Expected $case.Calls -Actual $calls.Count `
                    -Message "$because, makes only the calls before it"
                Assert-Equal -Expected 0 -Actual $run.Output.Count -Message "$because, returns nothing"
                Assert-That -Condition ($null -ne $run.Error) -Message "$because, raises a terminating error"
                Assert-Equal -Expected $case.Failure -Actual $run.Error.Exception.Message `
                    -Message "$because, raises the failure that was not thrown"
            }
            finally {
                Remove-FakeGitHubCli -Fixture $fake
            }
        }
    }
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
