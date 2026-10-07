#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$secret = 'SENTINEL_SECRET_123'
$escape = { param([string]$Text) [WildcardPattern]::Escape($Text) }
$repo = New-GitTestRepo
$folder = New-GitTestFolder
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a config value that git refuses (a key with no section)
    $refused = Get-GitCallOutcome { Set-GitConfig -Name 'nosection' -Value $secret -RepoPath $repo -Verbose }
    $firstLine = ($refused.Message -split "`n")[0]

    # Assert
    $refusedFirst = "Setting nosection failed: git -c core.longpaths=true -C $repo config nosection '***' (exit 2)"
    Assert-Equal -Expected $refusedFirst `
        -Actual $firstLine -Message 'A config value is hidden in the command line of the failure message'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $refused -Text $secret) `
        -Message 'and in the error''s target, its rendering, Get-Error, $Error[0] and every verbose line'
    Assert-Equal -Expected $refused.Message -Actual $refused.Target `
        -Message 'the target being that message'
    $refusedLine = "Setting nosection: git -c core.longpaths=true -C $repo config nosection ***"
    Assert-That -Condition ($refused.Verbose -contains $refusedLine) `
        -Message 'The verbose line shows *** in place of the value'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a value that git itself echoes in what it prints
    $echoed = Get-GitCallOutcome {
        & $module {
            param($r, $s)
            Invoke-GitCommand -Activity 'Reading' -RepoPath $r -Mask $s -Verbose `
                -Arguments @('-c', "core.autocrlf=$s", 'config', '--get', '--bool', 'core.autocrlf')
        } $repo $secret
    }

    # Assert
    $expectedEcho = "Reading failed: git -c core.longpaths=true -C $repo -c 'core.autocrlf=***' config --get" +
    " --bool core.autocrlf (exit 128)`nfatal: bad boolean config value '***' for 'core.autocrlf'"
    Assert-Equal -Expected $expectedEcho -Actual $echoed.Message `
        -Message 'A value is hidden in each line git printed, as well as in the command line'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $echoed -Text $secret) `
        -Message 'and everywhere else the failure shows'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - the same call, tolerated
    $tolerated = & $module {
        param($r, $s)
        Invoke-GitCommand -Activity 'Reading' -RepoPath $r -Mask $s -Tolerant `
            -Arguments @('-c', "core.autocrlf=$s", 'config', '--get', '--bool', 'core.autocrlf')
    } $repo $secret

    # Assert
    Assert-Equal -Expected "fatal: bad boolean config value '***' for 'core.autocrlf'" -Actual $tolerated.Message `
        -Message 'A tolerated call''s Message, which an error quotes, hides the value'
    Assert-Equal -Expected @("fatal: bad boolean config value '$secret' for 'core.autocrlf'") `
        -Actual @($tolerated.ErrorOutput) -Message 'while its ErrorOutput is kept exactly as git printed it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - -WhatIf with a config value
    $whatIf = Get-WhatIfOutput -CaptureError {
        Set-GitConfig -Name 'test.key' -Value $secret -RepoPath $repo -WhatIf
    }
    $setLine = "What if: Performing the operation ""Set config value"" on target ""$repo config"

    # Assert
    Assert-Equal -Expected @("$setLine test.key"".") -Actual $whatIf.Messages `
        -Message '-WhatIf names the key and shows no value'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a config key that carries a credential, the usual way a CI job
    # injects a token
    $key = "url.https://x-access-token:$secret@github.com/.insteadOf"
    $shownKey = 'url.https://***@github.com/.insteadOf'

    # Act - in a folder that is no repository
    $noRepo = Get-GitCallOutcome {
        Set-GitConfig -Name $key -Value 'https://github.com/' -RepoPath $folder -Verbose
    }
    $noRepoStart = & $escape "Setting $shownKey failed: '$folder' is not inside a git repository ("

    # Assert
    Assert-That -Condition ($noRepo.Message -like "$noRepoStart*") `
        -Message 'A key that names a credential is hidden in the not-in-a-repository error'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $noRepo -Text $secret) `
        -Message 'and everywhere else that error shows'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the same key under -WhatIf, and written for real with -Verbose
    $keyWhatIf = Get-WhatIfOutput -CaptureError {
        Set-GitConfig -Name $key -Value 'https://github.com/' -RepoPath $repo -WhatIf
    }
    $keyVerbose = Get-GitCallOutcome {
        Set-GitConfig -Name $key -Value 'https://github.com/' -RepoPath $repo -Verbose
    }

    # Assert
    Assert-Equal -Expected @("$setLine $shownKey"".") -Actual $keyWhatIf.Messages `
        -Message '-WhatIf hides the credential in the key'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $keyVerbose -Text $secret) `
        -Message '-Verbose hides it in the ShouldProcess line and in the line for git'
    $keyLine = "Setting $shownKey`: git -c core.longpaths=true -C $repo config $shownKey ***"
    Assert-That -Condition ($keyVerbose.Verbose -contains $keyLine) `
        -Message 'which shows the key hidden and the value as ***'
    Assert-Equal -Expected 'https://github.com/' -Actual (git -C $repo config --get $key) `
        -Message 'while the key is still written as it was given'

    #───────────────────────────────────────────────────────────────────────────
    # Act - reading a key that git cannot read
    $brokenKey = "url.https://x-access-token:$secret@github.com/"
    $broken = Get-GitCallOutcome { Get-GitConfig -Name $brokenKey -RepoPath $repo }

    # Assert
    $brokenStart = & $escape 'Reading url.https://***@github.com/ failed (exit 1): '
    Assert-That -Condition ($broken.Message -like "$brokenStart*") `
        -Message 'A key that names a credential is hidden in the error for a config git cannot read'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $broken -Text $secret) `
        -Message 'and everywhere else that error shows'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a remote given as a bare token, host and path
    $bare = Get-GitCallOutcome { Sync-GitRemote -Name "$secret@github.com/o/r" -RepoPath $repo }

    # Assert
    Assert-Equal -Expected "Fetching failed: '***@github.com/o/r' is not a remote, a URL, or a path that exists." `
        -Actual $bare.Message -Message 'A remote that is a token, a host and a path is hidden in the not-a-remote error'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $bare -Text $secret) `
        -Message 'and everywhere else that error shows'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a URL given as a remote's name, in a folder that is no repository
    $url = "https://u:$secret@host/o/r"
    $named = Get-GitCallOutcome { Get-GitRemote -Name $url -RepoPath $folder }

    # Assert
    $namedStart = & $escape 'Reading the https://***@host/o/r remote failed (exit 128): '
    Assert-That -Condition ($named.Message -like "$namedStart*") `
        -Message 'A URL given as a remote''s name is hidden in the error for a remote git cannot read'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $named -Text $secret) `
        -Message 'and everywhere else that error shows'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a URL given as the name of a remote to add
    $added = Get-GitCallOutcome { Set-GitRemote -Name $url -Url 'https://example.com/x.git' -RepoPath $repo }

    # Assert
    $invalidName = "Adding the https://***@host/o/r remote failed: " +
    "'https://***@host/o/r' is not a valid remote name."
    Assert-Equal -Expected $invalidName -Actual $added.Message `
        -Message 'A URL given as the name of a new remote is hidden in the invalid-name error'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $added -Text $secret) `
        -Message 'and everywhere else that error shows'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a remote that is itself named like a token, host and path
    $tokenName = "$secret@github.com/o/r"
    git -C $repo remote add $tokenName 'https://example.com/x.git' 2>&1 | Out-Null

    # Act
    $removeWhatIf = Get-WhatIfOutput -CaptureError { Remove-GitRemote -Name $tokenName -RepoPath $repo -WhatIf }
    $removeVerbose = Get-GitCallOutcome { Remove-GitRemote -Name $tokenName -RepoPath $repo -WhatIf -Verbose }

    # Assert
    $removeLine = "What if: Performing the operation ""Remove remote"" on target " +
    """$repo remote ***@github.com/o/r""."
    Assert-Equal -Expected @($removeLine) -Actual $removeWhatIf.Messages `
        -Message '-WhatIf hides the credential in the name of a remote it would remove'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $removeVerbose -Text $secret) `
        -Message 'and so does -Verbose'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
