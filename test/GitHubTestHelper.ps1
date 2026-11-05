using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Net
using namespace System.Net.Sockets

# Shared across every TaffarelJr.GitHub.* module's own tests - the fixture
# belongs to no single one of them, so it sits at the test root rather than
# inside any one module's own test tree.
function New-FakeGitHubCli {
    <#
    .SYNOPSIS
        Puts a fake gh ahead of the real one on PATH that records every
        call and answers each with canned output and an exit code.
    .DESCRIPTION
        Not exported - a test-only fixture, shared by the tests of every
        TaffarelJr.GitHub.* module rather than reimplemented per file.

        The fake is a gh.ps1 script. PowerShell resolves a .ps1 on PATH
        ahead of an executable, even one in the same folder, and runs it
        in-process, so the module's real invocation path - ProcessInvocation
        splatting the argument array and piping -StdIn - is what gets
        exercised, with no seam inside the module. Piped input reaches the
        script as $input, and its exit sets $LASTEXITCODE, as a native gh's
        would.

        Being in-process, it records the strings PowerShell would pass, not
        the bytes a native gh would read: an encoding, a byte-order mark,
        the newline -StdIn adds, Windows command-line quoting, and gh's own
        reading of its flags are all invisible here. Those are pinned by
        contract tests against the real gh and Start-FakeGitHubServer.

        The script finds its own files through $PSScriptRoot, so no path is
        written into it and a temp folder holding a quote cannot break it.
    .PARAMETER Output
        The lines the fake prints, whatever it is asked.
    .PARAMETER ErrorOutput
        The lines the fake writes to stderr - the error stream, which a
        captured call sees as error records - whatever it is asked. An
        empty line stays empty.
    .PARAMETER ExitCode
        The exit code the fake returns, whatever it is asked.
    .PARAMETER Sequence
        One answer per call instead - each a hashtable with any of Output,
        ErrorOutput, and ExitCode - in call order. The last answer repeats
        for every call after it.
    .PARAMETER RecordEnvironment
        Names of environment variables to record on every call, as the
        fake saw them.

        Whether or not any are given, a native shim (gh.cmd, or a gh shell
        script) sits beside the script, so a call that runs gh as a process
        of its own - Invoke-GitHubCommand -Environment - reaches the same
        fake and never the real gh with this machine's login. That route
        refuses an argument holding a double quote for a batch file on
        Windows, so such a call cannot be faked there.
    .OUTPUTS
        A fixture object (Path, CallLog, OriginalPath) for
        Get-FakeGitHubCall and Remove-FakeGitHubCli.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Single')]
    param(
        [Parameter(ParameterSetName = 'Single')]
        [AllowEmptyString()]
        [string[]]$Output = @(),

        [Parameter(ParameterSetName = 'Single')]
        [AllowEmptyString()]
        [string[]]$ErrorOutput = @(),

        [Parameter(ParameterSetName = 'Single')]
        [int]$ExitCode = 0,

        [Parameter(Mandatory, ParameterSetName = 'Sequence')]
        [IDictionary[]]$Sequence,

        [string[]]$RecordEnvironment = @()
    )

    $path = Join-Path ([Path]::GetTempPath()) "gh-fake-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $path | Out-Null
    $callLog = Join-Path $path 'calls'
    New-Item -ItemType Directory -Path $callLog | Out-Null

    if ($PSCmdlet.ParameterSetName -eq 'Single') {
        $Sequence = @(@{ Output = $Output; ErrorOutput = $ErrorOutput; ExitCode = $ExitCode })
    }

    $answers = foreach ($answer in $Sequence) {
        $lines = @{ Output = [string[]]@(); ErrorOutput = [string[]]@() }
        foreach ($stream in 'Output', 'ErrorOutput') {
            if ($answer.Contains($stream) -and $null -ne $answer[$stream]) {
                $lines[$stream] = [string[]]@($answer[$stream])
            }
        }

        [PSCustomObject]@{
            Output      = $lines.Output
            ErrorOutput = $lines.ErrorOutput
            ExitCode    = [int]$answer['ExitCode']
        }
    }

    @($answers) | Export-Clixml -LiteralPath (Join-Path $path 'answers.xml')
    $RecordEnvironment | Export-Clixml -LiteralPath (Join-Path $path 'environment.xml')

    $fake = @(
        '$items = @($input)'
        '$piped = $items.Count -gt 1 -or ($items.Count -eq 1 -and $null -ne $items[0])'
        '$calls = Join-Path $PSScriptRoot ''calls'''
        '$index = @(Get-ChildItem -LiteralPath $calls -Filter ''*.xml'').Count'
        '$files = @{}'
        'foreach ($argument in $args) {'
        '    if ($argument -and [System.IO.Path]::IsPathRooted($argument) -and'
        '        (Test-Path -LiteralPath $argument -PathType Leaf)) {'
        '        $files[$argument] = [System.IO.File]::ReadAllText($argument)'
        '    }'
        '}'
        '$environment = @{}'
        'foreach ($name in @(Import-Clixml -LiteralPath (Join-Path $PSScriptRoot ''environment.xml''))) {'
        '    $environment[$name] = [Environment]::GetEnvironmentVariable($name)'
        '}'
        '$call = [PSCustomObject]@{'
        '    Arguments   = @($args)'
        '    StdIn       = (@($items | Where-Object { $null -ne $_ }) -join "`n")'
        '    StdInPiped  = $piped'
        '    Files       = $files'
        '    Environment = $environment'
        '}'
        '$log = Join-Path $calls (''{0:D4}.xml'' -f $index)'
        'Export-Clixml -LiteralPath $log -InputObject $call'
        '$answers = @(Import-Clixml -LiteralPath (Join-Path $PSScriptRoot ''answers.xml''))'
        '$answer = $answers[[Math]::Min($index, $answers.Count - 1)]'
        'foreach ($line in @($answer.Output)) {'
        '    $line'
        '}'
        'foreach ($line in @($answer.ErrorOutput)) {'
        '    if ($env:GH_FAKE_SHIM) {'
        '        [Console]::Error.WriteLine($line)'
        '    }'
        '    else {'
        '        Write-Error -Exception ([Exception]::new($line)) -ErrorAction Continue'
        '    }'
        '}'
        'exit $answer.ExitCode'
    )
    Set-Content -LiteralPath (Join-Path $path 'gh.ps1') -Value $fake

    $pwsh = (Get-Process -Id $PID).Path
    $script = Join-Path $path 'gh.ps1'
    if ($IsWindows) {
        $shim = @(
            '@set GH_FAKE_SHIM=1'
            "@`"$pwsh`" -NoProfile -NonInteractive -File `"$script`" %*"
            '@exit /b %ERRORLEVEL%'
        )
        Set-Content -LiteralPath (Join-Path $path 'gh.cmd') -Value $shim
    }
    else {
        $quote = { param($Text) "'" + $Text.Replace("'", "'\''") + "'" }
        $shim = "#!/bin/sh`nGH_FAKE_SHIM=1 exec $(& $quote $pwsh) -NoProfile -NonInteractive -File" +
        " $(& $quote $script) `"`$@`"`n"
        $shimPath = Join-Path $path 'gh'
        [File]::WriteAllText($shimPath, $shim)
        & chmod '+x' $shimPath
    }

    $fixture = [PSCustomObject]@{
        Path         = $path
        CallLog      = $callLog
        OriginalPath = $env:PATH
    }
    $env:PATH = "$path$([Path]::PathSeparator)$env:PATH"

    return $fixture
}

function Get-FakeGitHubCall {
    <#
    .SYNOPSIS
        Returns every call the fake gh has recorded, oldest first.
    .DESCRIPTION
        Not exported - a test-only fixture. Each call is read back exactly
        as recorded: a string that looks like a date or a number stays the
        string it was.
    .PARAMETER Fixture
        The object New-FakeGitHubCli returned.
    .OUTPUTS
        One object per call, oldest first: Arguments, StdIn (the piped
        lines joined with a line feed), StdInPiped (whether anything was
        piped at all, an empty string included), Files (a hashtable of
        path to text for every argument that named an existing file when
        gh was called), and Environment (the variables RecordEnvironment
        named, $null for one that was not set).

        Files holds each file's decoded text, not its bytes: a UTF-8
        byte-order mark is dropped in the reading. That a text file reaches
        gh byte for byte - no BOM, line endings as given - is pinned by
        Core's own Use-GitHubTextFile test, not by the tests of the modules
        that use it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture
    )

    if (-not (Test-Path -LiteralPath $Fixture.CallLog)) {
        return
    }

    $logs = Get-ChildItem -LiteralPath $Fixture.CallLog -Filter '*.xml' | Sort-Object -Property Name
    foreach ($log in $logs) {
        $recorded = Import-Clixml -LiteralPath $log.FullName
        [PSCustomObject]@{
            Arguments   = [object[]]@($recorded.Arguments)
            StdIn       = [string]$recorded.StdIn
            StdInPiped  = [bool]$recorded.StdInPiped
            Files       = [hashtable]$recorded.Files
            Environment = [hashtable]$recorded.Environment
        }
    }
}

function Remove-FakeGitHubCli {
    <#
    .SYNOPSIS
        Takes the fake gh back off PATH and deletes it.
    .DESCRIPTION
        Not exported - a test-only fixture. Tolerates a folder that is
        already gone, so a test's own finally block never fails on
        cleanup it does not strictly need.
    .PARAMETER Fixture
        The object New-FakeGitHubCli returned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture
    )

    $env:PATH = $Fixture.OriginalPath
    if (Test-Path -LiteralPath $Fixture.Path) {
        Remove-Item -LiteralPath $Fixture.Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-LiveGitHub {
    <#
    .SYNOPSIS
        Reports whether the real gh is authenticated, so a live test can
        skip cleanly where it is not.
    .DESCRIPTION
        Not exported - a test-only fixture. A live test exercises the real
        gh against a public repository to confirm the --json field names a
        function requests actually exist; where gh has no login and no
        GH_TOKEN, the file prints that it skipped and exits with an empty
        tally instead of failing.
    .OUTPUTS
        $true when gh reports an active, working login.
    #>
    [CmdletBinding()]
    param()

    $status = Invoke-NativeRead -Command 'gh' -Arguments @('auth', 'status', '--active')
    return $status.Ok
}

function Test-GitHubCliInstalled {
    <#
    .SYNOPSIS
        Reports whether the real gh executable is installed, so a contract
        test can skip cleanly where it is not.
    .DESCRIPTION
        Not exported - a test-only fixture. A contract test runs the real
        gh against Start-FakeGitHubServer and needs no login at all.
    .OUTPUTS
        $true when gh is an executable on PATH.
    #>
    [CmdletBinding()]
    param()

    $found = Get-Command -Name 'gh' -CommandType Application -ErrorAction Ignore
    return $null -ne $found
}

function Start-FakeGitHubServer {
    <#
    .SYNOPSIS
        Starts a loopback HTTP server that the real gh sends every API
        request to, and points gh at it.
    .DESCRIPTION
        Not exported - a test-only fixture, for contract tests that must
        see what the real gh does with an argument vector: the request it
        builds (method, path, body bytes), how it reads a response, and the
        errors it refuses a flag with. Nothing reaches GitHub.

        The server listens on 127.0.0.1 only, on a free port, inside a
        runspace of this process. gh is pointed at it through this
        process's environment, saved first and put back by
        Stop-FakeGitHubServer: GH_HOST is github.localhost, which gh talks
        to over plain HTTP at api.github.localhost, reached through
        HTTP_PROXY; GH_TOKEN is a fake token; GH_CONFIG_DIR is a new, empty
        folder, so no stored login, alias, or setting of this machine is
        read; GH_EDITOR names a program that does not exist, so a command
        that wanted an editor fails at once instead of waiting.

        HTTPS_PROXY points at the server too, so a call that names a real
        host - --hostname github.com, a github.com URL - asks the server
        for a tunnel instead of reaching GitHub. The server records that
        request (Method CONNECT, Path the host and port) and refuses it
        with a 403, so gh fails with no real response. A tunnel to a host
        outside github.com is refused too but not recorded, so stray
        background traffic cannot land among a test's requests. NO_PROXY is
        cleared, so no host is exempt. GH_TELEMETRY is false and
        DO_NOT_TRACK is 1, so gh sends no telemetry at all.

        Always stop it in a finally block.
    .PARAMETER Route
        The answers, keyed by request path and query. A key is matched
        exactly first, then as a wildcard pattern, in order. Each value is a
        hashtable with any of Status (default 200), Body (default '{}'),
        and Headers (a hashtable). A request matching no key gets a 404.
    .OUTPUTS
        A fixture object for Get-FakeGitHubRequest and
        Stop-FakeGitHubServer.
    #>
    [CmdletBinding()]
    param(
        [IDictionary]$Route = @{}
    )

    $listener = [TcpListener]::new([IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port

    $state = [hashtable]::Synchronized(@{
            Stop     = $false
            Port     = $port
            Routes   = $Route
            Requests = [ArrayList]::Synchronized([ArrayList]::new())
            Errors   = [ArrayList]::Synchronized([ArrayList]::new())
        })

    $serve = {
        param($Listener, $State, $Owner)

        function Read-Line {
            param($Stream)

            $bytes = [System.Collections.Generic.List[byte]]::new()
            while ($true) {
                $next = $Stream.ReadByte()
                if ($next -lt 0) {
                    break
                }

                $bytes.Add([byte]$next)
                if ($bytes.Count -ge 2 -and $bytes[$bytes.Count - 2] -eq 13 -and $next -eq 10) {
                    break
                }
            }

            return [System.Text.Encoding]::ASCII.GetString($bytes.ToArray()).TrimEnd("`r", "`n")
        }

        function Read-Exactly {
            param($Stream, [int]$Count)

            $buffer = [byte[]]::new($Count)
            $read = 0
            while ($read -lt $Count) {
                $got = $Stream.Read($buffer, $read, $Count - $read)
                if ($got -le 0) {
                    break
                }

                $read += $got
            }

            return , $buffer
        }

        while (-not $State.Stop -and $Owner.RunspaceStateInfo.State -eq 'Opened') {
            try {
                $pending = $Listener.Pending()
            }
            catch [InvalidOperationException] {
                break
            }

            if (-not $pending) {
                Start-Sleep -Milliseconds 20
                continue
            }

            $client = $Listener.AcceptTcpClient()
            try {
                $stream = $client.GetStream()
                $stream.ReadTimeout = 10000
                $requestLine = Read-Line $stream
                $headers = [ordered]@{}
                while ($true) {
                    $line = Read-Line $stream
                    if ($line -eq '') {
                        break
                    }

                    $colon = $line.IndexOf(':')
                    $headers[$line.Substring(0, $colon)] = $line.Substring($colon + 1).Trim()
                }

                $body = [System.Collections.Generic.List[byte]]::new()
                if ("$($headers['Transfer-Encoding'])" -match 'chunked') {
                    while ($true) {
                        $size = [Convert]::ToInt32((Read-Line $stream).Split(';')[0].Trim(), 16)
                        if ($size -eq 0) {
                            Read-Line $stream | Out-Null
                            break
                        }

                        $body.AddRange([byte[]](Read-Exactly $stream $size))
                        Read-Line $stream | Out-Null
                    }
                }
                elseif ($headers['Content-Length']) {
                    $body.AddRange([byte[]](Read-Exactly $stream ([int]$headers['Content-Length'])))
                }

                $parts = $requestLine.Split(' ')
                $tunnel = $parts[0] -eq 'CONNECT'
                $path = $parts[1]
                if (-not $tunnel) {
                    $path = ([uri]::new([uri]'http://api.github.localhost/', $parts[1])).PathAndQuery
                }

                $bytes = $body.ToArray()
                # A tunnel to a host that is not GitHub's is background traffic, never a test's request.
                if (-not $tunnel -or $path -match '^([^:]+\.)?github\.com:') {
                    $State.Requests.Add([PSCustomObject]@{
                            Method  = $parts[0]
                            Path    = $path
                            Headers = $headers
                            Body    = $bytes
                            Text    = [System.Text.Encoding]::UTF8.GetString($bytes)
                        }) | Out-Null
                }

                $answer = $null
                if ($tunnel) {
                    $answer = @{ Status = 403; Body = '{"message":"The fake server opens no tunnel to a real host."}' }
                }
                elseif ($State.Routes.Contains($path)) {
                    $answer = $State.Routes[$path]
                }
                else {
                    foreach ($key in $State.Routes.PSBase.Keys) {
                        if ($path -like $key) {
                            $answer = $State.Routes[$key]
                            break
                        }
                    }
                }

                $status = 404
                $text = '{"message":"Not Found"}'
                $extra = @{}
                if ($null -ne $answer) {
                    $status = if ($answer['Status']) { [int]$answer['Status'] } else { 200 }
                    $text = if ($answer.Contains('Body')) { [string]$answer['Body'] } else { '{}' }
                    $extra = if ($answer['Headers']) { $answer['Headers'] } else { @{} }
                }

                $payload = [System.Text.Encoding]::UTF8.GetBytes($text)
                $head = [System.Text.StringBuilder]::new()
                $reason = if ($tunnel) { 'Tunnel Refused By The Fake Server' } else { 'Answer' }
                $head.Append("HTTP/1.1 $status $reason`r`n") | Out-Null
                $head.Append("Content-Type: application/json; charset=utf-8`r`n") | Out-Null
                $head.Append("Content-Length: $($payload.Length)`r`n") | Out-Null
                $head.Append("Connection: close`r`n") | Out-Null
                foreach ($name in $extra.PSBase.Keys) {
                    $head.Append("$($name): $($extra[$name])`r`n") | Out-Null
                }

                $head.Append("`r`n") | Out-Null
                $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head.ToString())
                $stream.Write($headBytes, 0, $headBytes.Length)
                $stream.Write($payload, 0, $payload.Length)
                $stream.Flush()
            }
            catch {
                $State.Errors.Add($_.ToString()) | Out-Null
            }
            finally {
                $client.Close()
            }
        }
    }

    $runspace = [powershell]::Create()
    $owner = [runspace]::DefaultRunspace
    $runspace.AddScript($serve).AddArgument($listener).AddArgument($state).AddArgument($owner) | Out-Null
    $handle = $runspace.BeginInvoke()
    $server = [PSCustomObject]@{
        Port        = $port
        Listener    = $listener
        State       = $state
        Runspace    = $runspace
        Handle      = $handle
        ConfigDir   = $null
        Environment = [List[object[]]]::new()
    }

    try {
        $server.ConfigDir = Join-Path ([Path]::GetTempPath()) "gh-config-$([Guid]::NewGuid())"
        New-Item -ItemType Directory -Path $server.ConfigDir -ErrorAction Stop | Out-Null

        $proxy = "http://127.0.0.1:$port"
        $environment = @(
            , @('GH_HOST', 'github.localhost')
            , @('GH_TOKEN', 'fake-token-for-a-contract-test')
            , @('GH_ENTERPRISE_TOKEN', 'fake-token-for-a-contract-test')
            , @('GITHUB_TOKEN', $null)
            , @('GITHUB_ENTERPRISE_TOKEN', $null)
            , @('GH_CONFIG_DIR', $server.ConfigDir)
            , @('GH_REPO', $null)
            , @('GH_DEBUG', $null)
            , @('GH_EDITOR', (Join-Path $server.ConfigDir 'no-such-editor'))
            , @('GH_PROMPT_DISABLED', '1')
            , @('GH_NO_UPDATE_NOTIFIER', '1')
            , @('GH_TELEMETRY', 'false')
            , @('DO_NOT_TRACK', '1')
            , @('HTTP_PROXY', $proxy)
            , @('HTTPS_PROXY', $proxy)
            , @('NO_PROXY', $null)
        )

        # Variable names are case-sensitive outside Windows, and Go reads both spellings.
        if (-not $IsWindows) {
            $environment += , @('http_proxy', $proxy)
            $environment += , @('https_proxy', $proxy)
            $environment += , @('no_proxy', $null)
        }

        foreach ($pair in $environment) {
            $server.Environment.Add(@($pair[0], [Environment]::GetEnvironmentVariable($pair[0])))
            [Environment]::SetEnvironmentVariable($pair[0], $pair[1])
        }
    }
    catch {
        Stop-FakeGitHubServer -Server $server
        throw
    }

    return $server
}

function Get-FakeGitHubRequest {
    <#
    .SYNOPSIS
        Returns every request the fake server has received, oldest first.
    .DESCRIPTION
        Not exported - a test-only fixture.
    .PARAMETER Server
        The object Start-FakeGitHubServer returned.
    .OUTPUTS
        One object per request: Method, Path (path and query), Headers,
        Body (the raw bytes), and Text (the body decoded as UTF-8).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Server
    )

    $requests = $Server.State.Requests.ToArray()
    foreach ($request in $requests) {
        $request
    }
}

function Stop-FakeGitHubServer {
    <#
    .SYNOPSIS
        Stops the fake server and puts back the environment it changed.
    .DESCRIPTION
        Not exported - a test-only fixture. Waits for the request being
        answered, if any, to finish, closes the port, and deletes the
        empty gh config folder.
    .PARAMETER Server
        The object Start-FakeGitHubServer returned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Server
    )

    try {
        $Server.State.Stop = $true
        $Server.Runspace.EndInvoke($Server.Handle) | Out-Null
    }
    finally {
        $Server.Listener.Stop()
        $Server.Runspace.Dispose()
        foreach ($pair in $Server.Environment) {
            [Environment]::SetEnvironmentVariable($pair[0], $pair[1])
        }

        if ($Server.ConfigDir) {
            Remove-Item -LiteralPath $Server.ConfigDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Use-FakePollClock {
    <#
    .SYNOPSIS
        Gives a module's waiters a clock that only moves when they sleep,
        and a sleep that does not.
    .DESCRIPTION
        Not exported - a test-only fixture. Defines a New-GitHubPoll inside
        the module under test that passes every parameter on to Core's and
        swaps the poll's Clock and Sleep, so a wait's polls, pauses, and
        deadline depend only on the answers the fake gh gives - never on how
        fast the machine runs gh. The override takes exactly Core's
        parameters, so one Core does not know throws instead of being lost.
        It stays in place for the rest of the test file's process.
    .PARAMETER Module
        The imported module whose waiters should use the fake clock.
    .OUTPUTS
        The clock's state: Elapsed (a [TimeSpan], back to zero as each wait
        starts) and Slept (each pause asked for, in milliseconds, across
        waits until cleared).
    .EXAMPLE
        $clock = Use-FakePollClock -Module $module

        Makes Wait-GitHubWorkflowRun -TimeoutSeconds 1 -PollSeconds 30
        sleep exactly 1000 ms, on the fake clock.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSModuleInfo]$Module
    )

    $state = [PSCustomObject]@{
        Elapsed = [TimeSpan]::Zero
        Slept   = [List[int]]::new()
    }

    & $Module {
        param($State)
        $script:FakePollState = $State
        function script:New-GitHubPoll {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [int]$TimeoutSeconds,

                [Parameter(Mandatory)]
                [int]$PollSeconds
            )

            $poll = TaffarelJr.GitHub.Core\New-GitHubPoll @PSBoundParameters
            $fake = $script:FakePollState
            $fake.Elapsed = [TimeSpan]::Zero
            $clock = [PSCustomObject]@{}
            $clock | Add-Member -MemberType ScriptProperty -Name Elapsed -Value { $fake.Elapsed }.GetNewClosure()
            $poll.Clock = $clock
            $poll.Sleep = {
                param($Milliseconds)
                $fake.Slept.Add($Milliseconds)
                $fake.Elapsed += [TimeSpan]::FromMilliseconds($Milliseconds)
            }.GetNewClosure()
            return $poll
        }
    } $state

    return $state
}
