#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot 'GitHubWorkflowCommandsTestHelper.ps1')

if (-not $IsWindows) {
    exit (Skip-TestRun -Reason ('a folder on PATH holds no colon off Windows, and without one a path is not read as ' +
            'USER:PASSWORD@; here the drive''s own colon does'))
}

$originalPath = $env:PATH
$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder for PATH whose name looks like a credential, and the path file in place
    $null = New-CommandFile -Variable 'GITHUB_PATH' -Directory $sandbox
    $credentialPath = Join-Path $sandbox 'SENTINEL@h.example'

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Add-GitHubActionsPath -Path $credentialPath -WhatIf
    }

    # Assert
    Assert-Equal -Expected @('What if: Performing the operation "Add to PATH" on target "***@h.example".') `
        -Actual $whatIf.Messages -Message 'Add-GitHubActionsPath -WhatIf shows no credential in the folder'
    Assert-Equal -Expected $originalPath -Actual $env:PATH -Message 'and changes nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder name that holds the path separator
    $twoFolders = $credentialPath + [IO.Path]::PathSeparator + 'more'
    $expected = '''***@h.example;more'' holds the path separator '';'', so PATH would read it as more than one ' +
    'folder; add each folder with a call of its own.'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Add-GitHubActionsPath -Path $twoFolders
    } -MessageLike ([WildcardPattern]::Escape($expected)) `
        -Message 'and so does the refusal of a path that holds the path separator'
}
finally {
    $env:PATH = $originalPath
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
