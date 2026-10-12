#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    '',
    Justification = 'A test builds a fake secret from a literal.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubAccountTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Connect-GitHubAccount -Token 'ghp_secret'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'login', '--with-token') -Actual $call.Arguments `
        -Message 'gh is told to read the token from standard input'
    Assert-Equal -Expected 'ghp_secret' -Actual $call.StdIn -Message 'The token is what gets piped'
    Assert-That -Condition ($call.Arguments -notcontains 'ghp_secret') `
        -Message 'The token never appears among the arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option
$fake = New-FakeGitHubCli
try {
    # Act
    Connect-GitHubAccount -Token 't' -Hostname 'ghe.example' -GitProtocol https -InsecureStorage
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'auth', 'login', '--with-token', '--hostname', 'ghe.example', '--git-protocol', 'https', '--insecure-storage'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments -Message 'Each option becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a protocol in capitals, which gh accepts but would store as given
$fake = New-FakeGitHubCli
try {
    # Act
    Connect-GitHubAccount -Token 't' -GitProtocol 'SSH'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'login', '--with-token', '--git-protocol', 'ssh') -Actual $call.Arguments `
        -Message 'The protocol reaches gh in lower case'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - scopes, which gh refuses beside --with-token: a token's scopes are fixed when it is made
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Connect-GitHubAccount -Token 't' -Scopes 'gist'
    } -MessageLike "*parameter cannot be found*'Scopes'*" -Message 'There is no -Scopes to pass'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the token as a SecureString
$fake = New-FakeGitHubCli
try {
    # Act
    Connect-GitHubAccount -SecureToken (ConvertTo-SecureString -String 'ghp_from_secure' -AsPlainText -Force)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'login', '--with-token') -Actual $call.Arguments `
        -Message 'A SecureString token logs in the same way'
    Assert-Equal -Expected 'ghp_from_secure' -Actual $call.StdIn -Message 'and is piped as the plain token gh reads'
    Assert-That -Condition (($call.Arguments -join ' ') -notlike '*ghp_*') `
        -Message 'without ever appearing among the arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a native gh, which reads bytes, and a caller whose $OutputEncoding writes a byte-order mark
$token = "ghp_bytes_$([char]0x00E9)"
$savedHost = $env:GH_HOST
$savedTelemetry = $env:GH_TELEMETRY
$recorder = New-NativeStdInRecorder
$savedEncoding = $global:OutputEncoding
try {
    $global:OutputEncoding = [System.Text.UTF8Encoding]::new($true)

    # Act
    Connect-GitHubAccount -SecureToken (ConvertTo-SecureString -String $token -AsPlainText -Force)
    $seen = Get-NativeStdInHex -Fixture $recorder

    # Assert
    $expected = [Convert]::ToHexString([System.Text.Encoding]::UTF8.GetBytes($token + [Environment]::NewLine))
    Assert-Equal -Expected $expected -Actual $seen `
        -Message 'gh reads the token as UTF-8, no byte-order mark, one newline it trims, whatever $OutputEncoding is'
    Assert-Equal -Expected $recorder.Path -Actual $env:GH_CONFIG_DIR `
        -Message 'A gh that passed the recorder over would read only the recorder''s own config folder'
    Assert-Equal -Expected 'github.localhost' -Actual $env:GH_HOST -Message 'talk to no real host'
    Assert-Equal -Expected $null -Actual $env:GH_TOKEN -Message 'find no token in the environment'
    Assert-Equal -Expected 'false' -Actual $env:GH_TELEMETRY -Message 'send no telemetry'
    Assert-Equal -Expected '1' -Actual $env:DO_NOT_TRACK -Message 'by either switch'
}
finally {
    $global:OutputEncoding = $savedEncoding
    Remove-NativeStdInRecorder -Fixture $recorder
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - after the recorder is removed
Assert-Equal -Expected $savedHost -Actual $env:GH_HOST -Message 'Removing the recorder puts GH_HOST back'
Assert-Equal -Expected $savedTelemetry -Actual $env:GH_TELEMETRY -Message 'and GH_TELEMETRY'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - script tracing on, which prints the value of every variable assigned; only
# Connect-GitHubAccount's own lines are checked, since the helper that starts gh still shows the token
$fake = New-FakeGitHubCli
try {
    $script = @'
$secure = ConvertTo-SecureString -String 'ghp_traced_secret' -AsPlainText -Force
Set-PSDebug -Trace 2
try {
    Connect-GitHubAccount -SecureToken $secure
}
finally {
    Set-PSDebug -Off
}
'@

    # Act
    $trace = [string[]](Invoke-HostlessScript -Script $script).Debug
    $isConnect = [Predicate[string]] { $args[0] -like "*CALL function 'Connect-GitHubAccount'*" }
    $isCall = [Predicate[string]] { $args[0] -like '*CALL function *' }
    $start = [array]::FindIndex($trace, $isConnect)
    $end = [array]::FindIndex($trace, $start + 1, $isCall)
    $own = @($trace[$start..($end - 1)])

    # Assert
    Assert-That -Condition ($start -ge 0 -and $end -gt $start) `
        -Message 'Precondition: the trace shows Connect-GitHubAccount running, up to the next function it calls'
    Assert-Equal -Expected @() -Actual @($own -like '*ghp_traced_secret*') `
        -Message 'and none of Connect-GitHubAccount''s own lines holds the plain token in a variable'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a login gh rejects, with the token piped to it
$fake = New-FakeGitHubCli -ErrorOutput @('error validating token: HTTP 401') -ExitCode 1
try {
    # Act - a hand-rolled catch, not Assert-Throws: the message must also be
    # shown NOT to hold the token, and Assert-Throws can only match patterns
    $thrown = $null
    try {
        Connect-GitHubAccount -Token 'ghp_rejected_token'
    }
    catch {
        $thrown = $_
    }

    # Assert
    Assert-That -Condition ($null -ne $thrown) -Message 'A rejected token throws'
    Assert-That -Condition ($thrown.Exception.Message -like '*Logging in failed*error validating token*') `
        -Message 'with gh''s reason'
    Assert-That -Condition ($thrown.Exception.Message -notlike '*ghp_rejected_token*') `
        -Message 'and the token is not in the message'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a blank token, which gh would trim to nothing and answer with its browser login
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($blank in ' ', "`n", "`t `r`n") {
        Assert-Throws -ScriptBlock {
            Connect-GitHubAccount -Token $blank
        } -MessageLike '-Token is blank, and gh would fall back to its browser login: give the token.' `
            -Message "A -Token of '$blank' is refused"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty or blank SecureString, as Space and Enter at a masked prompt give
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    foreach ($blank in '', ' ', "`t`n") {
        $secure = [securestring]::new()
        foreach ($character in $blank.ToCharArray()) {
            $secure.AppendChar($character)
        }

        Assert-Throws -ScriptBlock {
            Connect-GitHubAccount -SecureToken $secure
        } -MessageLike '-SecureToken is blank, and gh would fall back to its browser login: give the token.' `
            -Message "A -SecureToken of '$blank' is refused"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - both forms of the token at once is ambiguous
Assert-Throws -ScriptBlock {
    Connect-GitHubAccount -Token 'a' -SecureToken (ConvertTo-SecureString -String 'b' -AsPlainText -Force)
} -MessageLike '*Parameter set cannot be resolved*' -Message 'A plain and a secure token together are refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no token at all, where PowerShell would prompt for the default parameter set's
$fake = New-FakeGitHubCli
try {
    # Act
    $default = (Get-Command -Name Connect-GitHubAccount).DefaultParameterSet

    # Assert
    Assert-Equal -Expected 'SecureToken' -Actual $default `
        -Message 'The token PowerShell prompts for is the SecureString, so what is typed is masked'
    Assert-Throws -ScriptBlock {
        Invoke-HostlessScript -Script 'Connect-GitHubAccount'
    } -MessageLike '*missing mandatory parameters: SecureToken.*' `
        -Message 'and with no host to prompt, it is -SecureToken that is missing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'with gh never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every other parameter, for both forms of the token
$fake = New-FakeGitHubCli
try {
    $secure = ConvertTo-SecureString -String 'ghp_SECURE_SENTINEL' -AsPlainText -Force
    $options = @{
        Hostname        = 'ghe.example'
        GitProtocol     = 'https'
        InsecureStorage = $true
    }

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Connect-GitHubAccount -Token 'ghp_SENTINEL' @options -WhatIf
        Connect-GitHubAccount -SecureToken $secure @options -WhatIf
    }

    # Assert
    $line = 'What if: Performing the operation "Store gh login" on target "ghe.example".'
    Assert-Equal -Expected @($line, $line) -Actual $whatIf.Messages -Message '-WhatIf names the host'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') -Message 'and never the token'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is never started, so no token reaches its standard input'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no -Hostname: gh logs in to github.com
$fake = New-FakeGitHubCli
try {
    $secure = ConvertTo-SecureString -String 'ghp_SECURE_SENTINEL' -AsPlainText -Force

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Connect-GitHubAccount -Token 'ghp_SENTINEL' -WhatIf
        Connect-GitHubAccount -SecureToken $secure -WhatIf
    }

    # Assert
    $line = 'What if: Performing the operation "Store gh login" on target "github.com".'
    Assert-Equal -Expected @($line, $line) -Actual $whatIf.Messages -Message '-WhatIf with no host names github.com'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') -Message 'and never the token'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Connect-GitHubAccount -Token ' ' -WhatIf
    } -MessageLike '-Token is blank, and gh would fall back to its browser login: give the token.' `
        -Message 'With -WhatIf, a blank token is still refused'

    # Act
    Connect-GitHubAccount -Token 'ghp_secret' -Hostname 'ghe.example' -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'login', '--with-token', '--hostname', 'ghe.example') -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
    Assert-Equal -Expected 'ghp_secret' -Actual $call.StdIn -Message 'and the token still goes on standard input'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
