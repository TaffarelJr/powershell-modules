#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a user whose environment names an editor, and whose config does
    $env:GIT_EDITOR = 'some-editor --wait'
    git -C $repo config core.editor 'another-editor --wait' 2>&1 | Out-Null

    # Act - what editor git would start
    try {
        $editor = @(& $module { param($r) Invoke-GitCommand -Activity 'Asking for the editor' -Arguments @('var', 'GIT_EDITOR') -RepoPath $r } $repo)
    }
    finally {
        Remove-Item Env:GIT_EDITOR
    }

    # Assert
    Assert-Equal -Expected 'true' -Actual ($editor -join '') `
        -Message 'The editor git would start is a command that does nothing, whatever the environment and config name'

    #───────────────────────────────────────────────────────────────────────────
    # Act - whether git may ask for a credential on the console
    $prompt = @(& $module {
            param($r)
            Invoke-GitCommand -Activity 'Reading the prompt setting' -RepoPath $r `
                -Arguments @('-c', 'alias.showprompt=!echo $GIT_TERMINAL_PROMPT', 'showprompt')
        } $repo)

    # Assert
    Assert-Equal -Expected '0' -Actual ($prompt -join '') `
        -Message 'Terminal prompts are off, so a command that needs a credential fails instead of waiting for one'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a command that succeeds and writes to both streams
    $both = @(& $module {
            param($r)
            Invoke-GitCommand -Activity 'Making noise' -RepoPath $r `
                -Arguments @('-c', 'alias.noisy=!echo to-stdout; echo to-stderr 1>&2', 'noisy')
        } $repo)

    # Assert
    Assert-Equal -Expected 'to-stdout' -Actual ($both -join '|') `
        -Message 'Only stdout comes back, so a warning cannot end up in what a caller parses'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a command that fails still shows stderr in its message
    Assert-Throws -ScriptBlock {
        & $module { param($r) Invoke-GitCommand -Activity 'Deleting a branch' -Arguments @(
            'branch', '-d', 'no-such-branch'
        ) -RepoPath $r } $repo
    } -MessageLike "*Deleting a branch failed*not found*" `
        -Message 'A failure''s message carries what git said on stderr'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the same failure, asked for as a result
    $failed = & $module { param($r) Invoke-GitCommand -Activity 'x' -Arguments @(
        'branch', '-d', 'no-such-branch'
    ) -RepoPath $r -Tolerant } $repo

    # Assert
    Assert-Equal -Expected $false -Actual $failed.Ok -Message 'A tolerated failure is a result, not a throw'
    Assert-Equal -Expected 0 -Actual @($failed.Output).Count `
        -Message 'its Output holds stdout alone, which here is nothing'
    Assert-That -Condition (($failed.ErrorOutput -join "`n") -like "*not found*") `
        -Message 'its ErrorOutput holds what git said'
    Assert-That -Condition ($failed.Message -like "*not found*") `
        -Message 'and its Message holds both, for an error to quote'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a tolerated call that succeeds
    $worked = & $module { param($r) Invoke-GitCommand -Activity 'x' -Arguments @(
        'rev-parse', '--is-inside-work-tree'
    ) -RepoPath $r -Tolerant } $repo

    # Assert
    Assert-Equal -Expected $true -Actual $worked.Ok -Message 'A tolerated success is Ok'
    Assert-Equal -Expected 'true' -Actual ($worked.Output -join '') -Message 'with its stdout'
    Assert-Equal -Expected 'true' -Actual $worked.Message -Message 'and a Message that is that output'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a repo named relative to PowerShell's location, which is not
    # the process's own working directory
    $parent = Split-Path -Parent $repo
    $elsewhere = Join-Path ([System.IO.Path]::GetTempPath()) "elsewhere-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $elsewhere | Out-Null

    # Act
    $relative = Use-SplitLocation -Location $parent -ProcessDirectory $elsewhere -ScriptBlock {
        & $module { param($name) Invoke-GitCommand -Activity 'Reading the branch' -Arguments @(
            'branch', '--show-current'
        ) -RepoPath $name } (Split-Path -Leaf $repo)
    }

    # Assert
    Assert-Equal -Expected 'main' -Actual ($relative -join '') `
        -Message 'A relative -RepoPath means PowerShell''s location, not the process''s working directory'
    Remove-Item -LiteralPath $elsewhere -Recurse -Force -ErrorAction SilentlyContinue

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a PowerShell drive rooted at the repo's parent folder
    New-PSDrive -Name 'GitTestDrive' -PSProvider FileSystem -Root $parent -Scope Global | Out-Null

    # Act
    try {
        $onDrive = & $module {
            param($leaf)
            Invoke-GitCommand -Activity 'Reading the branch' -Arguments @('branch', '--show-current') `
                -RepoPath "GitTestDrive:\$leaf"
        } (Split-Path -Leaf $repo)
    }
    finally {
        Remove-PSDrive -Name 'GitTestDrive' -Scope Global
    }

    # Assert
    Assert-Equal -Expected 'main' -Actual ($onDrive -join '') `
        -Message 'A -RepoPath on a PowerShell drive is resolved to the folder it names'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a user whose environment lets Git Credential Manager prompt
    $savedGcm = $env:GCM_INTERACTIVE
    $env:GCM_INTERACTIVE = 'always'

    # Act - whether Git Credential Manager may open a window
    try {
        $gcm = @(& $module {
                param($r)
                Invoke-GitCommand -Activity 'Reading the GCM setting' -RepoPath $r `
                    -Arguments @('-c', 'alias.showgcm=!echo $GCM_INTERACTIVE', 'showgcm')
            } $repo)
    }
    finally {
        $env:GCM_INTERACTIVE = $savedGcm
    }

    # Assert
    Assert-Equal -Expected 'never' -Actual ($gcm -join '') `
        -Message 'Git Credential Manager is told never to open a sign-in window'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a remote that asks for a password, and an askpass program named
    # in every place git looks for one
    $server = Start-GitTestAuthServer
    $recorder = New-GitTestRecorder
    $env:GIT_ASKPASS = $recorder.Program
    $env:SSH_ASKPASS = $recorder.Program
    git -C $repo config core.askPass $recorder.Program 2>&1 | Out-Null

    # Act
    try {
        $fetch = & $module {
            param($r, $u)
            Invoke-GitCommand -Activity 'Fetching' -Arguments @('fetch', $u) -RepoPath $r -Tolerant
        } $repo $server.Url
    }
    finally {
        Remove-Item -LiteralPath Env:GIT_ASKPASS, Env:SSH_ASKPASS
        Stop-GitTestAuthServer -Server $server
    }

    # Assert
    Assert-Equal -Expected $false -Actual $fetch.Ok -Message 'A fetch that needs a password fails'
    Assert-That -Condition ($fetch.Message -like '*terminal prompts disabled*') `
        -Message 'saying the credential could not be asked for'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $recorder.Log) `
        -Message 'and no askpass program was started, whether named by GIT_ASKPASS, core.askPass or SSH_ASKPASS'
    git -C $repo config --unset core.askPass 2>&1 | Out-Null
    Remove-Item -LiteralPath $recorder.Program, $recorder.Log -Force -ErrorAction SilentlyContinue

    #───────────────────────────────────────────────────────────────────────────
    # Act - a failure whose command line holds a URL with a password in it
    $token = 'fake-token-0123456789'
    $leaked = $null
    try {
        & $module {
            param($r, $t)
            Invoke-GitCommand -Activity "Asking http://user:$t@127.0.0.1:1/x.git" -RepoPath $r `
                -Arguments @('ls-remote', "http://user:$t@127.0.0.1:1/x.git")
        } $repo $token
    }
    catch {
        $leaked = $_.Exception.Message
    }

    # Assert
    $hidden = [WildcardPattern]::Escape('Asking http://***@127.0.0.1:1/x.git failed')
    Assert-That -Condition ($leaked -like "*$hidden*") `
        -Message 'A failure''s message hides the URL''s credential in the activity'
    Assert-That -Condition ($leaked -notlike "*$token*") `
        -Message 'and in the command line, so the password appears nowhere'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a public function that is not asked to be verbose
    $quiet = @(Get-GitBranch -RepoPath $repo 4>&1)
    $quietRecords = @($quiet | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })

    # Assert
    Assert-Equal -Expected 0 -Actual $quietRecords.Count `
        -Message 'Nothing is written to the verbose stream unless it is asked for'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the same call, with -Verbose
    $loud = @(Get-GitBranch -RepoPath $repo -Verbose 4>&1)
    $loudRecords = @($loud | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })
    $loudLines = @($loudRecords | ForEach-Object Message | Where-Object { $_ -like 'Reading the current branch: *' })

    # Assert
    $loudLine = "Reading the current branch: git -c core.longpaths=true -C $repo symbolic-ref --quiet HEAD"
    Assert-Equal -Expected @($loudLine) -Actual $loudLines `
        -Message '-Verbose on a public function shows what git is about to be asked, once, in the helper'
    Assert-Equal -Expected 'main' -Actual ($loud | Where-Object { $_ -is [string] }) `
        -Message 'and the answer still comes back'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the session as a whole is set to be verbose
    Set-Variable -Name VerbosePreference -Value 'Continue' -Scope Global

    # Act
    try {
        $session = @(Get-GitBranch -RepoPath $repo 4>&1)
    }
    finally {
        Set-Variable -Name VerbosePreference -Value 'SilentlyContinue' -Scope Global
    }

    # Assert
    $sessionLines = @($session | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } |
            ForEach-Object Message | Where-Object { $_ -like 'Reading the current branch: *' })
    Assert-Equal -Expected 1 -Actual $sessionLines.Count `
        -Message 'A $VerbosePreference set for the whole session is honored without -Verbose'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a command line with a URL that holds a password, an argument with a space, a quote, and an empty one
    $url = "http://user:$token@example.com/x.git"
    $shown = @(& $module {
            param($r, $u)
            Invoke-GitCommand -Activity "Asking $u" -RepoPath $r -Tolerant -Verbose `
                -Arguments @('check-ref-format', $u, 'two words', "it's here", "it's", '') 4>&1
        } $repo $url | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } |
            ForEach-Object Message | Where-Object { $_ -like 'Asking *' })

    # Assert
    $expected = "Asking http://***@example.com/x.git: git -c core.longpaths=true -C $repo check-ref-format" +
    " http://***@example.com/x.git 'two words' 'it''s here' it's ''"
    Assert-Equal -Expected @($expected) -Actual $shown `
        -Message 'The verbose line hides a URL''s credential in the activity and arguments, and quotes what needs it'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a config value that may be a secret
    $secret = "AUTHORIZATION: bearer $token"
    $configured = @(Set-GitConfig -Name 'http.extraheader' -Value $secret -RepoPath $repo -Verbose 4>&1)
    $configuredAll = @($configured | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } |
            ForEach-Object Message)
    $configuredLines = @($configuredAll | Where-Object { $_ -like 'Setting http.extraheader: *' })

    # Assert
    $hiddenValueLine = "Setting http.extraheader: git -c core.longpaths=true -C $repo config http.extraheader ***"
    Assert-That -Condition ($configuredLines -contains $hiddenValueLine) `
        -Message 'The verbose line of a config write shows *** in place of the value'
    Assert-Equal -Expected 0 -Actual @($configuredAll | Where-Object { $_ -like "*$token*" }).Count `
        -Message 'so the value appears in no verbose line of the whole call, ProcessInvocation''s included'
    Assert-Equal -Expected 0 -Actual @($configuredAll | Where-Object { $_ -like 'Running: *' }).Count `
        -Message 'because the helper is the only one that writes what git is asked, once'
    Assert-Equal -Expected $secret -Actual (git -C $repo config --get http.extraheader) `
        -Message 'while the value is still written'
    git -C $repo config --unset http.extraheader 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a second repository on another branch, with a new file, and the
    # variables a git hook sets, pointing at the first repository
    $other = New-GitTestRepo
    git -C $other checkout -q -b other-branch 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $other 'new-in-other.txt') -Value 'n' -NoNewline
    $env:GIT_DIR = Join-Path $repo '.git'
    $env:GIT_INDEX_FILE = Join-Path $repo '.git' 'index'

    # Act
    try {
        $otherBranch = @(& $module {
                param($r)
                Invoke-GitCommand -Activity 'Reading the branch' -Arguments @('branch', '--show-current') -RepoPath $r
            } $other)
        & $module { param($r) Invoke-GitCommand -Activity 'Staging' -Arguments @(
            'add', '-A'
        ) -RepoPath $r } $other | Out-Null
    }
    finally {
        Remove-Item -LiteralPath Env:GIT_DIR, Env:GIT_INDEX_FILE
    }

    # Assert
    Assert-Equal -Expected 'other-branch' -Actual ($otherBranch -join '') `
        -Message 'A -RepoPath wins over an inherited GIT_DIR'
    Assert-Equal -Expected @('a.txt') -Actual @(git -C $repo ls-files) `
        -Message 'and over GIT_INDEX_FILE, so the first repository''s index is untouched'
    Assert-Equal -Expected @('a.txt', 'new-in-other.txt') -Actual @(git -C $other ls-files) `
        -Message 'while the second repository''s index has the new file'
    Remove-GitTestRepo -Path $other
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a machine with no git on its PATH
$savedPath = $env:PATH
$env:PATH = ''
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { Invoke-GitCommand -Activity 'Reading the branch' -Arguments @('branch') -Tolerant }
    } -MessageLike '*Reading the branch failed: git was not found on PATH*' `
        -Message 'A tolerated call says git is missing, rather than answering as if the thing asked about were not there'
    Assert-Throws -ScriptBlock {
        & $module { Invoke-GitCommand -Activity 'Reading the branch' -Arguments @('branch') }
    } -MessageLike '*Reading the branch failed: could not run git*' -Message 'and so does an untolerated one'
}
finally {
    $env:PATH = $savedPath
}

exit (Complete-TestRun)
