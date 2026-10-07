using namespace System.IO

# A test must see only what it sets up: not a signing key, a hooks folder, or a
# pull.rebase from the machine it happens to run on, and never a write to the
# real global config. So the global config is the null device - reads see
# nothing, writes are dropped - and the system config is skipped. Each test file
# runs in its own process, so there is nothing to put back.
$env:GIT_CONFIG_GLOBAL = '/dev/null'
$env:GIT_CONFIG_NOSYSTEM = '1'

# Nor may a test reach a repository it did not make: run from a git hook, the
# suite inherits variables that point every git call at the hook's repository.
# The list is the module's own, which every test file imports first.
$gitRepositoryVariables = @(& (Get-Module -Name TaffarelJr.Git) { Get-GitRepositoryVariable })
foreach ($gitRepositoryVariable in $gitRepositoryVariables) {
    Remove-Item -LiteralPath "Env:$gitRepositoryVariable" -ErrorAction SilentlyContinue
}

# Every fixture lives under the temp folder, and a "not a repository" folder
# must stay one on a machine whose home folder is a repository (dotfiles):
# git looks for a repository no higher than the temp folder's children.
$env:GIT_CEILING_DIRECTORIES = [Path]::GetTempPath().TrimEnd('\', '/')

function Get-GitTestSkipReason {
    <#
    .SYNOPSIS
        Returns why this machine's git cannot run a test file, or nothing
        when it can.
    .DESCRIPTION
        Not exported - a test-only fixture. The isolation above needs git
        2.32, the first to read GIT_CONFIG_GLOBAL: an older git would read,
        and a test of -Global would write, the developer's real global config.
        New-GitTestRepo needs 2.28 for --initial-branch.
    .PARAMETER Minimum
        The oldest git the file can run on. Defaults to 2.32.
    .OUTPUTS
        The reason, for Skip-TestRun; nothing when git is new enough.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [version]$Minimum = '2.32'
    )

    $git = Get-Command -Name 'git' -CommandType Application -ErrorAction SilentlyContinue
    if (-not $git) {
        return 'git is not installed'
    }

    $text = (git --version) -join ' '
    if ($text -notmatch '(\d+)\.(\d+)\.(\d+)') {
        return "the git version could not be read from '$text'"
    }

    $version = [version]::new($Matches[1], $Matches[2], $Matches[3])
    if ($version -lt $Minimum) {
        return "these tests need git $Minimum or later, and this is git $version"
    }
}

function New-GitTestGlobalConfig {
    <#
    .SYNOPSIS
        Points git's global config at a real, empty throwaway file, for a test
        of something that reads or writes it.
    .DESCRIPTION
        Not exported - a test-only fixture. Remove-GitTestGlobalConfig puts the
        null device back.
    .OUTPUTS
        The file's full path.
    #>
    [CmdletBinding()]
    param()

    $path = Join-Path ([Path]::GetTempPath()) "git-global-$([Guid]::NewGuid()).config"
    New-Item -ItemType File -Path $path | Out-Null
    $env:GIT_CONFIG_GLOBAL = $path
    return $path
}

function Remove-GitTestGlobalConfig {
    <#
    .SYNOPSIS
        Deletes a file New-GitTestGlobalConfig made, and makes the global config
        the null device again.
    .PARAMETER Path
        The file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $env:GIT_CONFIG_GLOBAL = '/dev/null'
    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
}

function Install-FakeGpg {
    <#
    .SYNOPSIS
        Makes a repo's commits signable, and their signatures verifiable, by a
        stand-in for gpg that always succeeds - no key, no real signature.
    .DESCRIPTION
        Not exported - a test-only fixture, for a test of what git writes when
        a commit is signed. The stand-in is a small shell script; delete it
        with Remove-Item when the test is done.
    .PARAMETER Repo
        The repo to set up.
    .OUTPUTS
        The stand-in's path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Repo
    )

    $shim = Join-Path ([Path]::GetTempPath()) "fake-gpg-$([Guid]::NewGuid())"
    $script = @'
#!/bin/sh
case "$*" in
  *--verify*)
    echo "[GNUPG:] NEWSIG"
    echo "[GNUPG:] GOODSIG 0123456789ABCDEF Test <test@example.com>"
    echo "[GNUPG:] VALIDSIG 0123456789ABCDEF 2026-01-01 1767225600 0 4 0 1 8 00 0123456789ABCDEF"
    echo "[GNUPG:] TRUST_ULTIMATE 0 pgp"
    echo "gpg: Good signature from \"Test <test@example.com>\"" >&2
    exit 0 ;;
  *)
    cat > /dev/null
    echo "[GNUPG:] SIG_CREATED D 1 8 00 1767225600 0123456789ABCDEF" >&2
    echo "-----BEGIN PGP SIGNATURE-----"
    echo ""
    echo "ZmFrZXNpZw=="
    echo "-----END PGP SIGNATURE-----"
    exit 0 ;;
esac
'@
    [File]::WriteAllText($shim, ($script -replace "`r`n", "`n"))
    if (-not $IsWindows) {
        [File]::SetUnixFileMode($shim, [UnixFileMode]'UserRead, UserWrite, UserExecute')
    }

    git -C $Repo config gpg.program ($shim -replace '\\', '/') 2>&1 | Out-Null
    git -C $Repo config user.signingkey 0123456789ABCDEF 2>&1 | Out-Null
    return $shim
}

function New-GitTestRepo {
    <#
    .SYNOPSIS
        Creates a throwaway git repo under the temp folder, with a
        deterministic identity and line-ending config so a test never
        depends on the host machine's own git config.
    .DESCRIPTION
        Not exported - a test-only fixture, shared across this module's
        test files rather than reimplemented per file.
    .PARAMETER NoCommit
        Skips the initial commit, for a test that needs a repo with no
        history at all.
    .OUTPUTS
        The new repo's full path.
    #>
    [CmdletBinding()]
    param(
        [switch]$NoCommit
    )

    $path = Join-Path ([Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $path | Out-Null

    git -C $path init --quiet --initial-branch=main 2>&1 | Out-Null
    git -C $path config core.autocrlf false 2>&1 | Out-Null
    git -C $path config user.name 'Test' 2>&1 | Out-Null
    git -C $path config user.email 'test@example.com' 2>&1 | Out-Null

    if (-not $NoCommit) {
        Set-Content -LiteralPath (Join-Path $path 'a.txt') -Value 'line1' -NoNewline
        git -C $path add -A 2>&1 | Out-Null
        git -C $path commit --quiet -m 'initial' 2>&1 | Out-Null
    }

    return $path
}

function New-GitTestPathRepo {
    <#
    .SYNOPSIS
        Creates a throwaway git repo, as New-GitTestRepo does, with the given
        files committed in it, for a test of the ways a path can be written.
    .DESCRIPTION
        Not exported - a test-only fixture. Each file holds 'base', and its
        folders are created as needed. Delete it with Remove-GitTestRepo.
    .PARAMETER Path
        The files to commit, relative to the repository root, with forward
        slashes.
    .OUTPUTS
        The new repo's full path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path
    )

    $repo = New-GitTestRepo
    foreach ($p in $Path) {
        $file = Join-Path $repo $p
        New-Item -ItemType Directory -Path (Split-Path $file -Parent) -Force | Out-Null
        Set-Content -LiteralPath $file -Value 'base' -NoNewline
    }

    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add path files' 2>&1 | Out-Null
    return $repo
}

function Remove-GitTestRepo {
    <#
    .SYNOPSIS
        Deletes a repo New-GitTestRepo created.
    .DESCRIPTION
        Not exported - a test-only fixture. Tolerates a path that is
        already gone, so a test's own finally block never fails on
        cleanup it does not strictly need.
    .PARAMETER Path
        The repo to delete.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-GitTestRepoState {
    <#
    .SYNOPSIS
        Returns everything a git command could change in a repo, as one text,
        for a test that checks a call changed nothing.
    .DESCRIPTION
        Not exported - a test-only fixture. Covers HEAD, every ref (stash,
        tags and remote-tracking ones included), the index with its conflict
        stages, the status, the repo's own config, the names at the top of the
        git folder (MERGE_HEAD, rebase-merge, FETCH_HEAD and the like), and
        the content of every file in the working tree.
    .PARAMETER Repo
        The repo to read.
    .OUTPUTS
        The state, one line per fact.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Repo
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("HEAD: $(git -C $Repo symbolic-ref -q HEAD 2>$null) $(git -C $Repo rev-parse -q --verify HEAD 2>$null)")
    $lines.AddRange([string[]]@(git -C $Repo for-each-ref '--format=ref: %(refname) %(objectname)' 2>$null))
    $lines.AddRange([string[]]@(git -C $Repo ls-files -s 2>$null | ForEach-Object { "index: $_" }))
    $lines.AddRange([string[]]@(git -C $Repo status --porcelain -uall 2>$null | ForEach-Object { "status: $_" }))
    $lines.AddRange([string[]]@(git -C $Repo config --local --list 2>$null | ForEach-Object { "config: $_" }))

    $gitDir = Join-Path $Repo '.git'
    $names = Get-ChildItem -LiteralPath $gitDir -Force -Name | Sort-Object
    $lines.AddRange([string[]]@($names | ForEach-Object { "git folder: $_" }))

    $files = Get-ChildItem -LiteralPath $Repo -Recurse -File -Force |
        Where-Object { -not $_.FullName.StartsWith($gitDir, [StringComparison]::Ordinal) }
    foreach ($file in $files | Sort-Object FullName) {
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $lines.Add("file: $([Path]::GetRelativePath($Repo, $file.FullName)) $hash")
    }

    return $lines -join "`n"
}

function New-GitTestFolder {
    <#
    .SYNOPSIS
        Creates an empty folder under the temp folder that is no git
        repository.
    .DESCRIPTION
        Not exported - a test-only fixture. Delete it with Remove-GitTestRepo.
    .OUTPUTS
        The folder's full path.
    #>
    [CmdletBinding()]
    param()

    $path = Join-Path ([Path]::GetTempPath()) "not-a-repo-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function New-GitTestRecorder {
    <#
    .SYNOPSIS
        Creates a program that writes a line to a log each time it runs, for
        a test that checks whether git started it.
    .DESCRIPTION
        Not exported - a test-only fixture. The program is a small shell
        script that logs its arguments and prints 'recorded', so as an askpass
        program it also answers a prompt. Nothing is logged until it runs.
        Delete both files with Remove-Item when the test is done.
    .OUTPUTS
        An object with Program, the script's path with forward slashes, and
        Log, the path of the log it writes.
    #>
    [CmdletBinding()]
    param()

    $base = Join-Path ([Path]::GetTempPath()) "git-recorder-$([Guid]::NewGuid())"
    $program = "$base.sh" -replace '\\', '/'
    $log = "$base.log"
    $script = "#!/bin/sh`necho `"ran: `$*`" >> '$($log -replace '\\', '/')'`necho recorded`n"
    [File]::WriteAllText($program, $script)
    if (-not $IsWindows) {
        [File]::SetUnixFileMode($program, [UnixFileMode]'UserRead, UserWrite, UserExecute')
    }

    return [PSCustomObject]@{
        Program = $program
        Log     = $log
    }
}

function Start-GitTestAuthServer {
    <#
    .SYNOPSIS
        Starts a web server on the loopback address that answers every
        request with '401 Unauthorized', asking for a user name and password.
    .DESCRIPTION
        Not exported - a test-only fixture, for a test of what git does when
        a remote wants a credential. Nothing leaves the machine. Stop it with
        Stop-GitTestAuthServer.
    .OUTPUTS
        An object with Url, a repository URL on the server, and what
        Stop-GitTestAuthServer needs.
    #>
    [CmdletBinding()]
    param()

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $server = [powershell]::Create()
    $null = $server.AddScript({
            param($Listener)

            $answer = "HTTP/1.1 401 Unauthorized`r`nWWW-Authenticate: Basic realm=`"test`"`r`n" +
            "Content-Length: 0`r`nConnection: close`r`n`r`n"
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($answer)
            while ($true) {
                try {
                    $client = $Listener.AcceptTcpClient()
                }
                catch {
                    return
                }

                try {
                    $stream = $client.GetStream()
                    $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
                    do {
                        $line = $reader.ReadLine()
                    } while ($line)

                    $stream.Write($bytes, 0, $bytes.Length)
                    $stream.Flush()
                }
                finally {
                    $client.Close()
                }
            }
        }).AddArgument($listener)
    $handle = $server.BeginInvoke()

    return [PSCustomObject]@{
        Url        = "http://127.0.0.1:$($listener.LocalEndpoint.Port)/repo.git"
        Listener   = $listener
        PowerShell = $server
        Handle     = $handle
    }
}

function Stop-GitTestAuthServer {
    <#
    .SYNOPSIS
        Stops a server Start-GitTestAuthServer started.
    .PARAMETER Server
        What Start-GitTestAuthServer returned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Server
    )

    $Server.Listener.Stop()
    $Server.PowerShell.Stop()
    $Server.PowerShell.Dispose()
}

function Get-GitCallOutcome {
    <#
    .SYNOPSIS
        Runs a script block and reports everything a secret could leak
        through: what it said, and how it failed.
    .DESCRIPTION
        Not exported - a test-only fixture. Collects the verbose lines as
        they are written, so those written before a failure are kept, and
        clears $Error first so $Error[0] is this call's own failure.
    .PARAMETER ScriptBlock
        The call to make.
    .OUTPUTS
        An object - Message, Target and the text PowerShell renders for the
        error (Rendered), what Get-Error shows for the error it was thrown as
        (Detail) and for $Error[0] (Last); all empty when nothing failed. Also
        Verbose, each verbose line, and Output, what was written to the
        pipeline.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $raised = $null
    $seen = [System.Collections.Generic.List[object]]::new()
    $global:Error.Clear()
    try {
        & $ScriptBlock 4>&1 | ForEach-Object { $seen.Add($_) }
    }
    catch {
        $raised = $_
    }

    $record = [System.Management.Automation.VerboseRecord]
    $verbose = @($seen | Where-Object { $_ -is $record } | ForEach-Object { $_.Message })
    $output = @($seen | Where-Object { $_ -isnot $record })
    return [PSCustomObject]@{
        Message  = if ($raised) { $raised.Exception.Message } else { '' }
        Target   = if ($raised) { $raised.TargetObject } else { $null }
        Rendered = if ($raised) { ($raised | Out-String) } else { '' }
        Detail   = if ($raised) { ($raised | Get-Error | Out-String) } else { '' }
        Last     = if ($raised) { (Get-Error | Out-String) } else { '' }
        Verbose  = $verbose
        Output   = $output
    }
}

function Get-LeakingSurface {
    <#
    .SYNOPSIS
        Names each place a text shows up in what Get-GitCallOutcome reported.
    .DESCRIPTION
        Not exported - a test-only fixture. An empty answer means the text
        is in none of the message, the error's target, the way PowerShell
        renders the error, what Get-Error shows, and the verbose lines.
    .PARAMETER Outcome
        What Get-GitCallOutcome returned.
    .PARAMETER Text
        The text that must appear nowhere.
    .OUTPUTS
        The name of each surface that holds the text, one at a time.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Outcome,

        [Parameter(Mandatory)]
        [string]$Text
    )

    $surfaces = [ordered]@{
        Message  = $Outcome.Message
        Target   = "$($Outcome.Target)"
        Rendered = $Outcome.Rendered
        Detail   = $Outcome.Detail
        Last     = $Outcome.Last
        Verbose  = $Outcome.Verbose -join "`n"
    }

    foreach ($name in $surfaces.Keys) {
        if ($surfaces[$name].Contains($Text)) {
            $name
        }
    }
}
