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
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository secret
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubSecret -Name 'NUGET_KEY' -Value 'hunter2' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'set', '--repo', 'o/r', '--', 'NUGET_KEY') -Actual $call.Arguments `
        -Message 'Only the name and repository are arguments, and the name comes last, after a --'
    Assert-Equal -Expected 'hunter2' -Actual $call.StdIn -Message 'The value reaches gh on standard input'
    Assert-That -Condition ($call.Arguments -notcontains 'hunter2') `
        -Message 'The value never appears among the arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a secret given as a SecureString
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubSecret -Name 'NUGET_KEY' -SecureValue (ConvertTo-SecureString -String 'hunter2' -AsPlainText -Force)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'set', '--', 'NUGET_KEY') -Actual $call.Arguments `
        -Message 'A SecureString is named the same way'
    Assert-Equal -Expected 'hunter2' -Actual $call.StdIn `
        -Message 'and reaches gh as its text on standard input, never among the arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an organization secret limited to some repositories, options in mixed case
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubSecret -Name 'TOKEN' -Value 'v' -Organization 'org' -Visibility 'Selected' -Repos @('a', 'b') `
        -Application 'Actions'
    Set-GitHubSecret -Name 'TOKEN' -Value 'v' -Organization 'org' -Visibility selected -NoReposSelected
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @(
            'secret', 'set', '--org=org', '--app', 'actions', '--visibility', 'selected', '--repos', 'a,b', '--',
            'TOKEN'
        ) `
        -Actual $calls[0].Arguments `
        -Message 'Organization options become their gh flags, lower-cased for gh''s exact checks, repositories comma-joined'
    Assert-Equal `
        -Expected @('secret', 'set', '--org=org', '--visibility', 'selected', '--no-repos-selected', '--', 'TOKEN') `
        -Actual $calls[1].Arguments `
        -Message '-NoReposSelected becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an environment's secret and a user's, each with what goes with it
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubSecret -Name 'DEPLOY' -Value 'v' -Environment 'prod' -Repository 'o/r'
    Set-GitHubSecret -Name 'DEV' -Value 'v' -User -Repos 'o/a'
    Set-GitHubSecret -Name 'DEV' -Value 'v' -Environment '-x'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('secret', 'set', '--env=prod', '--repo', 'o/r', '--', 'DEPLOY') `
        -Actual $calls[0].Arguments `
        -Message 'An environment''s secret is set with --env, in its repository'
    Assert-Equal -Expected @('secret', 'set', '--user', '--repos', 'o/a', '--', 'DEV') -Actual $calls[1].Arguments `
        -Message 'A user''s with --user, and the repositories that may use it'
    Assert-Equal -Expected @('secret', 'set', '--env=-x', '--', 'DEV') -Actual $calls[2].Arguments `
        -Message 'The environment travels joined to its flag, so a dash-leading one stays a value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - secrets listed from two scopes, as Get-GitHubSecret returns them, given one new value
$listing = New-FakeGitHubCli -Output @('[{"name":"TOKEN","visibility":"all"}]')
try {
    $listed = @(
        Get-GitHubSecret -Organization 'org'
        Get-GitHubSecret -Environment 'prod' -Repository 'other/repo'
    )
}
finally {
    Remove-FakeGitHubCli -Fixture $listing
}

$fake = New-FakeGitHubCli
try {
    # Act
    $listed | Set-GitHubSecret -Value 'rotated'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('secret', 'set', '--org=org', '--app', 'actions', '--visibility', 'all', '--', 'TOKEN') `
        -Actual $calls[0].Arguments `
        -Message 'A piped organization secret is set in its organization, keeping the visibility it was listed with rather than gh''s private'
    Assert-Equal -Expected @('secret', 'set', '--env=prod', '--repo', 'other/repo', '--', 'TOKEN') `
        -Actual $calls[1].Arguments `
        -Message 'and an environment''s in that environment of its own repository'
    Assert-Equal -Expected @('rotated', 'rotated') -Actual @($calls.ForEach('StdIn')) `
        -Message 'each with the value on standard input'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listed private organization secret narrowed with -Repos or -NoReposSelected, and a repository secret set in an environment
$listedPrivate = [PSCustomObject]@{
    Name = 'TOKEN'
    Visibility = 'private'
    Organization = 'org'
    Application = 'actions'
}
$listedRepository = [PSCustomObject]@{ Name = 'TOKEN'; Visibility = ''; Repository = 'o/r'; Application = 'actions' }
$fake = New-FakeGitHubCli
try {
    # Act
    $listedPrivate | Set-GitHubSecret -Value 'v' -Repos 'a', 'b'
    $listedPrivate | Set-GitHubSecret -Value 'v' -NoReposSelected
    $listedRepository | Set-GitHubSecret -Value 'v' -Environment 'prod'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('secret', 'set', '--org=org', '--app', 'actions', '--repos', 'a,b', '--', 'TOKEN') `
        -Actual $calls[0].Arguments `
        -Message '-Repos makes the secret selected, so the listed visibility is not sent beside it, which gh would refuse'
    Assert-Equal -Expected @('secret', 'set', '--org=org', '--app', 'actions', '--no-repos-selected', '--', 'TOKEN') `
        -Actual $calls[1].Arguments `
        -Message 'as does -NoReposSelected'
    Assert-Equal -Expected @('secret', 'set', '--env=prod', '--repo', 'o/r', '--', 'TOKEN') `
        -Actual $calls[2].Arguments `
        -Message 'A piped repository secret''s actions Application is dropped beside -Environment, the only application an environment has'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}
#───────────────────────────────────────────────────────────────────────────────
# Arrange - an environment's secret piped with its own repository, an enterprise one with OWNER/REPO, and a repository one with -User
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Name = 'B'; Repository = 'o/r'; Environment = 'prod' } | Set-GitHubSecret -Value 'v' `
        -Repository 'o/r'
    [PSCustomObject]@{ Name = 'A'; Repository = 'ghe.io/o/r'; Application = 'actions' } | Set-GitHubSecret -Value 'v' `
        -Repository 'o/r'
    [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' } | Set-GitHubSecret -Value 'v' -User
    [PSCustomObject]@{
        Name = 'U'
        User = $true
        Application = 'codespaces'
        Visibility = 'selected'
    } | Set-GitHubSecret `
        -Value 'v' `
        -Organization 'org'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('secret', 'set', '--env=prod', '--repo', 'o/r', '--', 'B') -Actual $calls[0].Arguments `
        -Message 'An environment''s secret piped with its own repository keeps its environment'
    Assert-Equal -Expected @('secret', 'set', '--app', 'actions', '--repo', 'ghe.io/o/r', '--', 'A') `
        -Actual $calls[1].Arguments `
        -Message 'An enterprise secret piped with OWNER/REPO stays on its own host'
    Assert-Equal -Expected @('secret', 'set', '--user', '--', 'A') -Actual $calls[2].Arguments `
        -Message 'A piped actions Application is dropped beside -User, whose secrets are always Codespaces'''
    Assert-Equal -Expected @('secret', 'set', '--org=org', '--app', 'codespaces', '--', 'U') `
        -Actual $calls[3].Arguments `
        -Message 'A piped user secret set in an organization takes no visibility from the user secret'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}
#───────────────────────────────────────────────────────────────────────────────
# Arrange - many secrets from a dotenv file, given by a relative path
$folder = Join-Path ([IO.Path]::GetTempPath()) "env-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
Set-Content -LiteralPath (Join-Path $folder 'secrets.env') -Value 'A=1'
$fake = New-FakeGitHubCli
try {
    # Act
    Push-Location -LiteralPath $folder
    try {
        Set-GitHubSecret -EnvFile 'secrets.env' -Repository 'o/r'
    }
    finally {
        Pop-Location
    }

    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'set', '--env-file', (Join-Path $folder 'secrets.env'), '--repo', 'o/r') `
        -Actual $call.Arguments `
        -Message '-EnvFile becomes gh''s --env-file, as a full path, so it is found from wherever gh runs'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'Nothing is piped when the values come from a file'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a dotenv file with a byte-order mark, a UTF-16 one, one that is not there, a lone dash, and one given with piped secrets
$folder = Join-Path ([IO.Path]::GetTempPath()) "env-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$bom = Join-Path $folder 'bom.env'
[IO.File]::WriteAllBytes($bom, [byte[]](0xEF, 0xBB, 0xBF, 0x41, 0x3D, 0x31))
$utf16 = Join-Path $folder 'utf16.env'
[IO.File]::WriteAllText($utf16, 'A=1', [Text.UnicodeEncoding]::new($false, $true))
$plain = Join-Path $folder 'plain.env'
Set-Content -LiteralPath $plain -Value 'A=1'
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -EnvFile $bom
    } -MessageLike "-EnvFile '*bom.env' starts with a UTF-8 byte-order mark, which gh reads as part of the first name: save the file without one." `
        -Message 'A file starting with a byte-order mark is refused before gh is called'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -EnvFile 'no-such-file.env'
    } -MessageLike "-EnvFile 'no-such-file.env' is not a file." `
        -Message 'A file that is not there is refused with its name'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -EnvFile $utf16
    } -MessageLike "-EnvFile '*utf16.env' starts with a UTF-16 byte-order mark, and gh reads only UTF-8*" `
        -Message 'A UTF-16 file is refused, saying to save it as UTF-8'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{
            Name = 'A'
            Organization = 'org'
        }, [PSCustomObject]@{ Name = 'B'; Organization = 'org' } | Set-GitHubSecret `
            -EnvFile $plain
    } -MessageLike '*input object cannot be bound*' `
        -Message 'Piped secrets beside -EnvFile are refused, rather than setting the whole file once per secret'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -EnvFile '-'
    } -MessageLike "-EnvFile '-' would make gh read standard input: give the path of a file." `
        -Message 'A lone dash, which gh would read as standard input, is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty value, as text and as a SecureString
$fake = New-FakeGitHubCli
try {
    # Act
    $empty = 'The value is empty - give the secret a value, or delete it with Remove-GitHubSecret.'

    # Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value ''
    } -MessageLike $empty -Message 'An empty text value is refused with a message saying so'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -SecureValue ([securestring]::new())
    } -MessageLike $empty -Message 'and so is an empty SecureString, with the same message'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is called for neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names GitHub would refuse, and one it takes
$fake = New-FakeGitHubCli
try {
    # Act
    $refused = @('1KEY', 'GITHUB_TOKEN', 'github_token', 'MY KEY', 'MY-KEY', '--body')

    # Assert
    foreach ($name in $refused) {
        Assert-Throws -ScriptBlock {
            Set-GitHubSecret -Name $name -Value 'v'
        } -MessageLike "*'$name' is not a secret name: give letters, digits, and _, not led by a digit or GITHUB_." `
            -Message "'$name' is refused before anything is sent"
    }

    # Act
    Set-GitHubSecret -Name '_my_Key2' -Value 'v'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'gh is called only for the name GitHub takes'
    Assert-Equal -Expected @('secret', 'set', '--', '_my_Key2') -Actual $calls[0].Arguments `
        -Message 'which goes to gh as it was given'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - scopes and options gh refuses together, and a repository given as $null
$appAndEnvironment = '-Application and -Environment cannot be used together: an environment''s secrets are always Actions'', and a piped secret''s Application or Environment counts too. Give only one.'
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Environment 'prod' -User
    } -MessageLike '-Environment and -User cannot be used together: a secret lives in one place - a repository, one of its environments, an organization, or the user. Give only one.' `
        -Message 'An environment and the user together are refused, saying why'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -User -NoReposSelected
    } -MessageLike '-NoReposSelected works only with -Organization: only an organization''s secret can be kept from every repository. Give -Organization too, or leave -NoReposSelected off.' `
        -Message 'as is -NoReposSelected for the user, which gh refuses'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Environment 'prod' -Visibility all
    } -MessageLike '-Visibility and -Environment cannot be used together: only an organization''s secret has a visibility. Give only one.' `
        -Message 'and a visibility for an environment'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -User -Visibility all
    } -MessageLike '-Visibility works only with -Organization: only an organization''s secret has a visibility. Give -Organization too, or leave -Visibility off.' `
        -Message 'or for the user'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Repos 'a'
    } -MessageLike '-Repos works only with -Organization or -User: only their secrets are limited to some repositories. Give -Organization or -User too, or leave -Repos off.' `
        -Message 'and repositories for a repository''s own secret'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name '' -Value 'v'
    } -MessageLike "*'' is not a secret name*" -Message 'An empty name is refused with the name rule''s message'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Organization 'o_rg'
    } -MessageLike "*'o_rg' is not an organization name: give letters, digits, and dashes." `
        -Message 'and an organization name that is not one'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Organization 'org' -Repos 'a' -NoReposSelected
    } -MessageLike '-Repos and -NoReposSelected cannot be used together: one lets those repositories use the secret, the other lets none. Give only one.' `
        -Message '-Repos beside -NoReposSelected is refused, as gh would refuse it'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{
            Name = 'C'
            Visibility = 'selected'
            Organization = 'org'
            Application = 'actions'
        } | Set-GitHubSecret `
            -Value 'v'
    } -MessageLike 'Secret C is shared with selected repositories: give -Repos (or -NoReposSelected) to keep it limited, or give -Visibility.' `
        -Message 'A piped secret listed as selected is refused without a list, which gh would refuse too'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Organization 'org' -Visibility selected
    } -MessageLike '-Visibility selected works only with -Repos or -NoReposSelected: gh needs to know which repositories may use the secret. Give -Repos too, or leave -Visibility off.' `
        -Message '-Visibility selected without a list is refused'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Organization 'org' -Visibility All -Repos 'a'
    } -MessageLike '-Visibility all and -Repos cannot be used together: -Repos makes the secret selected. Give only one.' `
        -Message '-Visibility all beside -Repos is refused'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -User -Application actions
    } -MessageLike '-Application and -User cannot be used together: the user''s secrets are always Codespaces''. Give only one.' `
        -Message 'A non-Codespaces application for the user is refused here, not by gh'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'dependabot' } | Set-GitHubSecret -Value 'v' `
            -User
    } -MessageLike '-Application and -User cannot be used together: the user''s secrets are always Codespaces'', and a piped secret''s Application or User counts too. Give only one.' `
        -Message 'as is a piped Dependabot secret set for the user'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'U'; User = $true; Application = 'codespaces' } | Set-GitHubSecret -Value 'v' `
            -Environment 'prod'
    } -MessageLike 'Secret U is for codespaces, and environments hold only Actions secrets: leave -Environment off, or list an Actions secret.' `
        -Message 'A piped Codespaces secret set in an environment says what to do'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Organization 'org' -Visibility private -NoReposSelected
    } -MessageLike '-Visibility private and -NoReposSelected cannot be used together: -NoReposSelected makes the secret selected. Give only one.' `
        -Message 'as is -Visibility private beside -NoReposSelected'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Organization 'org' -Repos ''
    } -MessageLike '-Repos was given a blank name, so the secret would not be limited to the repositories meant. Give a value, or leave -Repos off.' `
        -Message 'A blank repository name is refused, rather than dropped to widen who can use the secret'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Organization 'org' -Repos 'a', ' '
    } -MessageLike '-Repos was given a blank name*' -Message 'as is one blank among others'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Organization 'org' -Repos @()
    } -MessageLike '-Repos was given no repositories, so the secret would not be limited to the repositories meant. Give a value, or leave -Repos off.' `
        -Message 'An empty list of repositories is refused, as a filter that matched nothing gives'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'KEY'; Repository = 'o/r'; Application = 'dependabot' } | Set-GitHubSecret `
            -Value 'v' `
            -Environment 'prod'
    } -MessageLike 'Secret KEY is for dependabot, and environments hold only Actions secrets: leave -Environment off, or list an Actions secret.' `
        -Message 'A piped secret of another application beside -Environment is still refused, saying what to do'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Environment 'prod' -Application actions
    } -MessageLike '-Application and -Environment cannot be used together: an environment''s secrets are always Actions''. Give only one.' `
        -Message 'An application for an environment is refused, saying why, with nothing about a pipe when nothing was piped'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'KEY'; Repository = 'o/r'; Environment = 'prod' } | Set-GitHubSecret -Value 'v' `
            -Application actions
    } -MessageLike $appAndEnvironment `
        -Message 'as is one beside a piped environment''s secret, which would otherwise be set in the repository instead'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of setting the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh refuses the secret, and the value must not appear in what is thrown
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 403: Resource not accessible') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'NUGET_KEY' -Value 'hunter2'
    } -MessageLike '*Setting secret NUGET_KEY failed*Resource not accessible*' `
        -Message 'A failure throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same failure, to read the message whole
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 403: Resource not accessible') -ExitCode 1
try {
    # Act
    $thrown = $null
    try {
        Set-GitHubSecret -Name 'NUGET_KEY' -Value 'hunter2'
    }
    catch {
        $thrown = $_.Exception.Message
    }

    # Assert
    Assert-That -Condition ($thrown -notlike '*hunter2*') -Message 'The value is nowhere in the failure message'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a text value, a SecureString, and a dotenv file, beside scopes and options
$folder = Join-Path ([IO.Path]::GetTempPath()) "env-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$plain = Join-Path $folder 'plain.env'
Set-Content -LiteralPath $plain -Value 'A=1'
$secure = ConvertTo-SecureString -String 'hunter2' -AsPlainText -Force
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(
        Set-GitHubSecret -Name 'KEY' -Value 'hunter2' -Environment 'prod' -Repository 'o/r' -WhatIf
        Set-GitHubSecret -Name 'KEY' -SecureValue $secure -Organization 'org' -Repos 'a', 'b' -WhatIf
        Set-GitHubSecret -EnvFile $plain -User -WhatIf
    )
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls `
        -Message 'With -WhatIf gh is not called, so no secret is set and no value is sent'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf:$false and -Confirm:$false beside scopes and options
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubSecret -Name 'KEY' -Value 'v' -Organization 'org' -Application 'dependabot' -Visibility 'selected' `
        -Repos 'a', 'b' `
        -WhatIf:$false `
        -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'secret', 'set', '--org=org', '--app', 'dependabot', '--visibility', 'selected', '--repos', 'a,b', '--',
            'KEY'
        ) `
        -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false set it as before, neither one reaching gh nor counting as a scope'
    Assert-Equal -Expected 'v' -Actual $call.StdIn -Message 'and the value still travels on standard input'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two listed secrets piped in with -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $secrets = @(
        [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' }
        [PSCustomObject]@{ Name = 'B'; Organization = 'org'; Visibility = 'all'; Application = 'actions' }
    )
    $out = @($secrets | Set-GitHubSecret -Value 'v' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf neither piped secret is set'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a dotenv file that has a byte-order mark, two scopes, and a piped selected secret
$folder = Join-Path ([IO.Path]::GetTempPath()) "env-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$bom = Join-Path $folder 'bom.env'
[IO.File]::WriteAllBytes($bom, [byte[]](0xEF, 0xBB, 0xBF, 0x41, 0x3D, 0x31))
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -EnvFile $bom -WhatIf
    } -MessageLike "-EnvFile '*bom.env' starts with a UTF-8 byte-order mark*" `
        -Message '-WhatIf still refuses a dotenv file with a byte-order mark'
    Assert-Throws -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value 'v' -Environment 'prod' -User -WhatIf
    } -MessageLike '-Environment and -User cannot be used together:*' -Message 'and two scopes at once'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'C'; Visibility = 'selected'; Organization = 'org' } | Set-GitHubSecret -Value 'v' `
            -WhatIf
    } -MessageLike 'Secret C is shared with selected repositories:*' `
        -Message 'and a piped selected secret without a list'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for a text value, a SecureString, and a dotenv file, each holding a sentinel
$sentinel = 'SENTINELzq9'
$folder = Join-Path ([IO.Path]::GetTempPath()) "env-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$plain = Join-Path $folder 'plain.env'
Set-Content -LiteralPath $plain -Value "A=$sentinel"
$secure = ConvertTo-SecureString -String $sentinel -AsPlainText -Force
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubSecret -Name 'KEY' -Value $sentinel -Environment 'prod' `
            -Repository "https://user:$sentinel@github.com/o/r" `
            -WhatIf
        Set-GitHubSecret -Name 'KEY' -SecureValue $secure -Organization 'org' -Application 'dependabot' -Repos 'a' `
            -WhatIf
        Set-GitHubSecret -EnvFile $plain -User -WhatIf
        Set-GitHubSecret -EnvFile $plain -Repository "https://user:$sentinel@github.com/o/r" -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Set secret" on target "o/r environment prod secret KEY".'
        'What if: Performing the operation "Set secret" on target "organization org dependabot secret KEY".'
        "What if: Performing the operation `"Set secrets from $plain`" on target `"the current user`"."
        "What if: Performing the operation `"Set secrets from $plain`" on target `"o/r`"."
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message '-WhatIf names each secret, or the dotenv file, in its scope, the repository without the credential'
    Assert-Equal -Expected @() -Actual @($result.Messages | Where-Object { $_.Contains($sentinel) }) `
        -Message 'and no line holds the value, the SecureString''s text, the file''s content, or the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two listed secrets piped in
$fake = New-FakeGitHubCli
try {
    # Act
    $secrets = @(
        [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'actions' }
        [PSCustomObject]@{ Name = 'B'; Organization = 'org'; Visibility = 'all'; Application = 'actions' }
    )
    $result = Get-WhatIfOutput -ScriptBlock { $secrets | Set-GitHubSecret -Value $sentinel -WhatIf }

    # Assert
    $expected = @(
        'What if: Performing the operation "Set secret" on target "o/r actions secret A".'
        'What if: Performing the operation "Set secret" on target "organization org actions secret B".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped secret gets its own line, where it was listed from, and neither holds the value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a call that fits more than one parameter set, run with no host so a missing mandatory parameter
# fails instead of asking for it
$shell = [PowerShell]::Create()
$null = $shell.AddScript({
        param($Root)

        $ErrorActionPreference = 'Stop'
        Import-Module (Join-Path $Root 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1')
        Import-Module (Join-Path $Root 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1')
        Import-Module (Join-Path $Root 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1')
        Set-GitHubSecret -Name 'N' -Environment 'e'
    }).AddArgument($repoRoot)
try {
    # Act / Assert
    Assert-Equal -Expected 'Value' -Actual (Get-Command Set-GitHubSecret).DefaultParameterSet `
        -Message 'A name and a value given as text is the default way to set a secret'
    Assert-Throws -ScriptBlock {
        $shell.Invoke()
    } -MessageLike '*missing mandatory parameters: Value.*' `
        -Message 'A name with no value asks for -Value, not for a parameter set to be resolved'
}
finally {
    $shell.Dispose()
}

exit (Complete-TestRun)
