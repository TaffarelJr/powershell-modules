#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The fake gh and the fake server in test/GitHubTestHelper.ps1 belong to no
# one module, but every GitHub module's tests rely on them; Core owns them.
$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot 'GitHubCoreTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake that answers each call in turn
$fake = New-FakeGitHubCli -Sequence @(
    @{ Output = @('first') }
    @{ Output = @('second'); ErrorOutput = @('warn', '', 'more'); ExitCode = 3 }
)
try {
    # Act
    $one = Invoke-GitHubCommand -Activity 'x' -Argument @('a') -Tolerant
    $two = Invoke-GitHubCommand -Activity 'x' -Argument @('b') -Tolerant
    $three = Invoke-GitHubCommand -Activity 'x' -Argument @('c') -Tolerant

    # Assert
    Assert-Equal -Expected @('first') -Actual $one.Output -Message '-Sequence gives the first answer to the first call'
    Assert-Equal -Expected 0 -Actual $one.ExitCode -Message 'with exit 0 when the answer gives none'
    Assert-Equal -Expected @(@('second'), @('warn', '', 'more'), 3) `
        -Actual @($two.Output, $two.ErrorOutput, $two.ExitCode) `
        -Message 'the second to the second, a blank stderr line kept blank'
    Assert-Equal -Expected @('second') -Actual $three.Output -Message 'and the last answer again to every call after'
    Assert-Equal -Expected @('a', 'b', 'c') `
        -Actual @((Get-FakeGitHubCall -Fixture $fake).ForEach({ $_.Arguments[0] })) `
        -Message 'Every call is recorded, oldest first'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file that exists, one that does not, and text that only looks like a date
$work = New-CoreTestFolder
$fake = New-FakeGitHubCli
try {
    $body = Join-Path $work 'here' 'body.md'
    [System.IO.File]::WriteAllText($body, "line one`nline two")

    # Act
    Invoke-GitHubCommand -Activity 'x' -Argument @('issue', 'create', '--body-file', $body, '--title', '2024-01-02T03:04:05Z', 'body.md', (Join-Path $work 'missing.md')) | Out-Null
    Invoke-GitHubCommand -Activity 'x' -Argument @('a') -StdIn '' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @($body) -Actual @($calls[0].Files.PSBase.Keys) `
        -Message 'Files records an argument that is the full path of an existing file, and nothing else'
    Assert-Equal -Expected "line one`nline two" -Actual $calls[0].Files[$body] `
        -Message 'with the file''s text at the time of the call'
    Assert-Equal -Expected '2024-01-02T03:04:05Z' -Actual $calls[0].Arguments[5] `
        -Message 'An argument that looks like a date is read back as the text it was'
    Assert-Equal -Expected @($false, '') -Actual @($calls[0].StdInPiped, $calls[0].StdIn) `
        -Message 'Nothing piped is StdInPiped $false'
    Assert-Equal -Expected @($true, '') -Actual @($calls[1].StdInPiped, $calls[1].StdIn) `
        -Message 'while an empty string piped is StdInPiped $true'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-CoreTestFolder -Path $work
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a temp folder whose path holds a single quote, as a profile like O'Brien would
$work = New-CoreTestFolder
$quoted = Join-Path $work "O'Brien"
New-Item -ItemType Directory -Path $quoted | Out-Null
$savedTemp = @($env:TMP, $env:TEMP, $env:TMPDIR)
$env:TMP = $quoted
$env:TEMP = $quoted
$env:TMPDIR = $quoted
try {
    $fake = New-FakeGitHubCli -Output @('answered')
}
finally {
    $env:TMP, $env:TEMP, $env:TMPDIR = $savedTemp
}

try {
    # Act
    $answer = Invoke-GitHubCommand -Activity 'x' -Argument @('a')

    # Assert
    Assert-That -Condition ($fake.Path.StartsWith($quoted)) `
        -Message "The fake lives under the quoted folder ($($fake.Path))"
    Assert-Equal -Expected 'answered' -Actual $answer -Message 'and still answers and records calls'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'one call recorded'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-CoreTestFolder -Path $work
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the fake server, asked directly rather than through gh
$savedHost = $env:GH_HOST
$env:GH_HOST = 'kept.example'
$client = [System.Net.Http.HttpClient]::new()
$server = Start-FakeGitHubServer -Route ([ordered]@{
        '/exact'   = @{ Status = 201; Body = '{"exact":true}'; Headers = @{ 'X-Test' = 'yes' } }
        '/wild/*'  = @{ Body = '{"wild":true}' }
        '/default' = @{}
    })
try {
    # Act
    $during = $env:GH_HOST
    $telemetry = @($env:GH_TELEMETRY, $env:DO_NOT_TRACK)
    $base = "http://127.0.0.1:$($server.Port)"
    $exact = $client.PostAsync("$base/exact", [System.Net.Http.StringContent]::new('é')).GetAwaiter().GetResult()
    $wild = $client.GetAsync("$base/wild/anything?x=1").GetAwaiter().GetResult()
    $default = $client.GetAsync("$base/default").GetAwaiter().GetResult()
    $missing = $client.GetAsync("$base/nowhere").GetAwaiter().GetResult()
    $tunnels = foreach ($target in 'dc.services.visualstudio.com:443', 'api.github.com:443') {
        $socket = [System.Net.Sockets.TcpClient]::new('127.0.0.1', $server.Port)
        try {
            $stream = $socket.GetStream()
            $connect = [System.Text.Encoding]::ASCII.GetBytes("CONNECT $target HTTP/1.1`r`nHost: $target`r`n`r`n")
            $stream.Write($connect, 0, $connect.Length)
            ([System.IO.StreamReader]::new($stream)).ReadLine()
        }
        finally {
            $socket.Dispose()
        }
    }
    $requests = @(Get-FakeGitHubRequest -Server $server)

    # Assert
    Assert-Equal -Expected 'github.localhost' -Actual $during -Message 'The server points gh at itself while it runs'
    Assert-Equal -Expected @('false', '1') -Actual $telemetry -Message 'and turns gh''s telemetry off'
    Assert-Equal `
        -Expected @('HTTP/1.1 403 Tunnel Refused By The Fake Server', 'HTTP/1.1 403 Tunnel Refused By The Fake Server') `
        -Actual @($tunnels) `
        -Message 'A tunnel to any host is refused'
    Assert-Equal -Expected @(201, '{"exact":true}', 'yes') `
        -Actual @([int]$exact.StatusCode, $exact.Content.ReadAsStringAsync().GetAwaiter().GetResult(), @($exact.Headers.GetValues('X-Test'))[0]) `
        -Message 'An exact route answers with its status, body, and headers'
    Assert-Equal -Expected '{"wild":true}' -Actual $wild.Content.ReadAsStringAsync().GetAwaiter().GetResult() `
        -Message 'A wildcard route matches the path and query'
    Assert-Equal -Expected @(200, '{}') `
        -Actual @([int]$default.StatusCode, $default.Content.ReadAsStringAsync().GetAwaiter().GetResult()) `
        -Message 'A route that gives nothing answers 200 with {}'
    Assert-Equal -Expected 404 -Actual ([int]$missing.StatusCode) -Message 'and a path no route matches answers 404'
    Assert-Equal `
        -Expected @('POST /exact', 'GET /wild/anything?x=1', 'GET /default', 'GET /nowhere', 'CONNECT api.github.com:443') `
        -Actual @($requests.ForEach({ "$($_.Method) $($_.Path)" })) `
        -Message 'Every request is recorded, oldest first, and a tunnel only to a GitHub host'
    Assert-Equal -Expected 'C3A9' -Actual ([Convert]::ToHexString($requests[0].Body)) -Message 'with its body''s bytes'
    Assert-Equal -Expected 'é' -Actual $requests[0].Text -Message 'and its body as text'
}
finally {
    $client.Dispose()
    Stop-FakeGitHubServer -Server $server
}

# Assert
Assert-Equal -Expected 'kept.example' -Actual $env:GH_HOST `
    -Message 'Stopping the server puts back the environment it changed'
Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $server.ConfigDir) `
    -Message 'and deletes its empty gh config folder'
$env:GH_HOST = $savedHost

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fake made without -RecordEnvironment, and a call that runs gh as a process of its own
$fake = New-FakeGitHubCli -Output @('fake answer')
try {
    # Act
    $answer = Invoke-GitHubCommand -Activity 'x' -Argument @('version') -Environment @{ GH_FAKE_PROBE = '1' }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 'fake answer' -Actual $answer `
        -Message 'A call with -Environment reaches the fake even without -RecordEnvironment, never the real gh'
    Assert-Equal -Expected @('version') -Actual @($calls.ForEach({ $_.Arguments })) `
        -Message 'and is recorded, with its arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a temp folder that is really a file, so the server cannot make its config folder
$work = New-CoreTestFolder
$notFolder = Join-Path $work 'not-a-folder'
[System.IO.File]::WriteAllText($notFolder, '')
$savedTemp = @($env:TMP, $env:TEMP, $env:TMPDIR, $env:GH_HOST)
$runspaces = @(Get-Runspace).Count
$env:TMP = $notFolder
$env:TEMP = $notFolder
$env:TMPDIR = $notFolder
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-FakeGitHubServer | Out-Null
    } -MessageLike 'Cannot create*' -Message 'A server whose start fails throws its reason'
}
finally {
    $env:TMP, $env:TEMP, $env:TMPDIR = $savedTemp[0..2]
    Remove-CoreTestFolder -Path $work
}

# Assert
Assert-Equal -Expected $runspaces -Actual @(Get-Runspace).Count -Message 'and stops its listener runspace first'
Assert-Equal -Expected $savedTemp[3] -Actual $env:GH_HOST -Message 'leaving the environment as it was'

exit (Complete-TestRun)
