#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestRepo
$folder = New-GitTestFolder
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Set-GitConfig -Name 'test.key' -Value 's3cret' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf writes nothing to the repo''s config'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Set config value"" on target ""$repo config test.key""."
    ) -Actual $run.Messages -Message '-WhatIf names the repository and the key, and not the value'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $globalConfig = New-GitTestGlobalConfig
    try {
        # Act - the global config
        $run = Get-WhatIfOutput { Set-GitConfig 'test.key' 's3cret' -Global -RepoPath $folder -WhatIf }

        # Assert
        Assert-Equal -Expected 0 -Actual (Get-Item -LiteralPath $globalConfig).Length `
            -Message '-WhatIf with -Global writes nothing to the global config'
        Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Global returns nothing'
        Assert-Equal -Expected @(
            'What if: Performing the operation "Set config value" on target "global config test.key".'
        ) -Actual $run.Messages -Message '-WhatIf with -Global names the global config, wherever -RepoPath points'
    }
    finally {
        Remove-GitTestGlobalConfig -Path $globalConfig
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitConfig -Name '-x' -Value 'v' -RepoPath $repo -WhatIf } `
        -MessageLike "*'-x' is blank or starts with '-'*" -Message '-WhatIf still refuses a key that starts with a dash'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Set-GitConfig -Name 'test.key' -Value 'v' -RepoPath $folder -WhatIf } `
        -MessageLike "Setting test.key failed: '$folder' is not inside a git repository (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Set-GitConfig -Name 'test.key' -Value 'v' -RepoPath $folder } `
        -MessageLike "Setting test.key failed: '$folder' is not inside a git repository (*" `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
