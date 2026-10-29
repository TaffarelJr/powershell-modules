#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository variable
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubVariable -Name 'CI_LANGUAGES' -Value 'dotnet,powershell' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'set', '--repo', 'o/r', '--', 'CI_LANGUAGES') -Actual $call.Arguments `
        -Message 'Only the name and repository are arguments, and the name comes last, after a --'
    Assert-Equal -Expected 'dotnet,powershell' -Actual $call.StdIn -Message 'The value reaches gh on standard input'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an organization variable limited to some repositories, and an environment's
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubVariable -Name 'V' -Value 'x' -Organization 'org' -Visibility 'Selected' -Repos @('a', 'b')
    Set-GitHubVariable -Name 'V' -Value 'x' -Environment 'prod' -Repository 'o/r'
    Set-GitHubVariable -Name 'V' -Value 'x' -Environment '-x'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('variable', 'set', '--org=org', '--visibility', 'selected', '--repos', 'a,b', '--', 'V') `
        -Actual $calls[0].Arguments `
        -Message 'Organization options become their gh flags, the visibility lower-cased for gh''s exact check'
    Assert-Equal -Expected @('variable', 'set', '--env=prod', '--repo', 'o/r', '--', 'V') -Actual $calls[1].Arguments `
        -Message 'An environment''s variable is set with --env, in its repository'
    Assert-Equal -Expected @('variable', 'set', '--env=-x', '--', 'V') -Actual $calls[2].Arguments `
        -Message 'The environment travels joined to its flag, so a dash-leading one stays a value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty value, which is legitimate for a variable, and a value that looks like an option
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubVariable -Name 'EMPTY' -Value ''
    Set-GitHubVariable -Name 'FLAG' -Value '--force'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected $true -Actual $calls[0].StdInPiped -Message 'An empty value is accepted and piped'
    Assert-Equal -Expected '' -Actual $calls[0].StdIn -Message 'as empty'
    Assert-Equal -Expected '--force' -Actual $calls[1].StdIn `
        -Message 'A value starting with a dash arrives intact, as it is not an argument'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - variables read from two scopes, as Get-GitHubVariable returns them, given one new value
$listing = New-FakeGitHubCli -Output @('[{"name":"V","value":"1","visibility":"all"}]')
try {
    $listed = @(
        Get-GitHubVariable -Organization 'org'
        Get-GitHubVariable -Environment 'prod' -Repository 'other/repo'
    )
}
finally {
    Remove-FakeGitHubCli -Fixture $listing
}

$fake = New-FakeGitHubCli
try {
    # Act
    $listed | Set-GitHubVariable -Value '2'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('variable', 'set', '--org=org', '--visibility', 'all', '--', 'V') `
        -Actual $calls[0].Arguments `
        -Message 'A piped organization variable is set in its organization, keeping the visibility it was read with rather than gh''s private'
    Assert-Equal -Expected @('variable', 'set', '--env=prod', '--repo', 'other/repo', '--', 'V') `
        -Actual $calls[1].Arguments `
        -Message 'and an environment''s in that environment of its own repository'
    Assert-Equal -Expected @('2', '2') -Actual @($calls.ForEach('StdIn')) `
        -Message 'each with the new value, not the listed one'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listed organization variable visible to all, narrowed with -Repos
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Name = 'V'; Visibility = 'all'; Organization = 'org' } | Set-GitHubVariable -Value 'x' -Repos 'a'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'set', '--org=org', '--repos', 'a', '--', 'V') -Actual $call.Arguments `
        -Message '-Repos makes the variable selected, so the listed visibility is not sent beside it, which gh would refuse'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}
#───────────────────────────────────────────────────────────────────────────────
# Arrange - an environment's variable piped with its own repository
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Name = 'B'; Repository = 'o/r'; Environment = 'prod' } | Set-GitHubVariable -Value 'v' `
        -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'set', '--env=prod', '--repo', 'o/r', '--', 'B') -Actual $call.Arguments `
        -Message 'It keeps its environment, so no repository-level namesake is written'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}
#───────────────────────────────────────────────────────────────────────────────
# Arrange - many variables from a dotenv file, given by a relative path
$folder = Join-Path ([IO.Path]::GetTempPath()) "env-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
Set-Content -LiteralPath (Join-Path $folder 'vars.env') -Value 'A=1'
$fake = New-FakeGitHubCli
try {
    # Act
    Push-Location -LiteralPath $folder
    try {
        Set-GitHubVariable -EnvFile 'vars.env'
    }
    finally {
        Pop-Location
    }

    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'set', '--env-file', (Join-Path $folder 'vars.env')) -Actual $call.Arguments `
        -Message '-EnvFile becomes gh''s --env-file, as a full path, so it is found from wherever gh runs'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'and nothing is piped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - files gh cannot be given: a byte-order mark, none there, a lone dash, a folder; and piped variables beside a file
$folder = Join-Path ([IO.Path]::GetTempPath()) "env-folder-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$bom = Join-Path $folder 'bom.env'
[IO.File]::WriteAllBytes($bom, [byte[]](0xEF, 0xBB, 0xBF, 0x41, 0x3D, 0x31))
$plain = Join-Path $folder 'plain.env'
Set-Content -LiteralPath $plain -Value 'A=1'
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -EnvFile $bom
    } -MessageLike "-EnvFile '*bom.env' starts with a UTF-8 byte-order mark*" `
        -Message 'A file starting with a byte-order mark is refused before gh is called'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -EnvFile 'no-such-file.env'
    } -MessageLike "-EnvFile 'no-such-file.env' is not a file." `
        -Message 'A file that is not there is refused with its name'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -EnvFile '-'
    } -MessageLike "-EnvFile '-' would make gh read standard input: give the path of a file." `
        -Message 'A lone dash, which gh would read as standard input, is refused'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -EnvFile $folder
    } -MessageLike "-EnvFile '*' is not a file." -Message 'A folder is not a dotenv file, and is refused'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'A'; Organization = 'org' } | Set-GitHubVariable -EnvFile $plain
    } -MessageLike '*input object cannot be bound*' `
        -Message 'Piped variables beside -EnvFile are refused, rather than setting the whole file once per variable'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names GitHub would refuse, scopes gh refuses together, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'GITHUB_SHA' -Value 'v'
    } -MessageLike "*'GITHUB_SHA' is not a variable name: give letters, digits, and _, not led by a digit or GITHUB_." `
        -Message 'A name with the GITHUB_ prefix is refused'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name '9LIVES' -Value 'v'
    } -MessageLike "*'9LIVES' is not a variable name*" -Message 'as is one starting with a digit'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Environment 'prod' -Organization 'org'
    } -MessageLike '-Environment and -Organization cannot be used together: a variable lives in one place - a repository, one of its environments, or an organization. Give only one.' `
        -Message 'An environment and an organization together are refused, saying why'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Environment 'prod' -Visibility all
    } -MessageLike '-Visibility and -Environment cannot be used together: only an organization''s variable has a visibility. Give only one.' `
        -Message 'A visibility for an environment is refused, saying why'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Name = 'C'; Visibility = 'selected'; Organization = 'org' } | Set-GitHubVariable -Value 'v'
    } -MessageLike 'Variable C is shared with selected repositories: give -Repos to keep it limited, or give -Visibility.' `
        -Message 'A piped variable read as selected is refused without a list'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Organization 'org' -Visibility selected
    } -MessageLike '-Visibility selected works only with -Repos: gh needs to know which repositories may use the variable. Give -Repos too, or leave -Visibility off.' `
        -Message '-Visibility selected without -Repos is refused'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Organization 'org' -Visibility private -Repos 'a'
    } -MessageLike '-Visibility private and -Repos cannot be used together: -Repos makes the variable selected. Give only one.' `
        -Message '-Visibility private beside -Repos is refused'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Visibility all
    } -MessageLike '-Visibility works only with -Organization: only an organization''s variable has a visibility. Give -Organization too, or leave -Visibility off.' `
        -Message 'A visibility for a repository''s own variable is refused with its own sentence'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Repos 'a'
    } -MessageLike '-Repos works only with -Organization: only an organization''s variable is limited to some repositories. Give -Organization too, or leave -Repos off.' `
        -Message 'and repositories for a repository''s own variable'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Environment ' '
    } -MessageLike "*-Environment is blank: give the environment's name, or leave it out." `
        -Message 'A blank environment is refused'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Organization 'org' -Repos $null
    } -MessageLike '-Repos was given a blank name, so the variable would not be limited to the repositories meant. Give a value, or leave -Repos off.' `
        -Message 'A blank list of repositories is refused, rather than dropped to widen who can use the variable'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Organization 'org' -Repos @()
    } -MessageLike '-Repos was given no repositories, so the variable would not be limited to the repositories meant. Give a value, or leave -Repos off.' `
        -Message 'as is an empty list'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of setting the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a value and with a dotenv file, beside scopes and options
$folder = Join-Path ([IO.Path]::GetTempPath()) "env-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$plain = Join-Path $folder 'plain.env'
Set-Content -LiteralPath $plain -Value 'A=1'
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(
        Set-GitHubVariable -Name 'V' -Value 'x' -Environment 'prod' -Repository 'o/r' -WhatIf
        Set-GitHubVariable -Name 'V' -Value 'x' -Organization 'org' -Repos 'a', 'b' -WhatIf
        Set-GitHubVariable -EnvFile $plain -Organization 'org' -Visibility 'all' -WhatIf
    )
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so no variable is set'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Set-GitHubVariable -Name 'V' -Value 'x' -Organization 'org' -Repos 'a', 'b' -WhatIf:$false -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'set', '--org=org', '--repos', 'a,b', '--', 'V') -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false set it as before, neither one reaching gh nor counting as a scope'
    Assert-Equal -Expected 'x' -Actual $call.StdIn -Message 'and the value still travels on standard input'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two listed variables piped in with -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $variables = @(
        [PSCustomObject]@{ Name = 'A'; Repository = 'o/r' }
        [PSCustomObject]@{ Name = 'B'; Organization = 'org'; Visibility = 'all' }
    )
    $out = @($variables | Set-GitHubVariable -Value 'v' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf neither piped variable is set'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a dotenv file that has a byte-order mark, and two scopes
$folder = Join-Path ([IO.Path]::GetTempPath()) "env-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$bom = Join-Path $folder 'bom.env'
[IO.File]::WriteAllBytes($bom, [byte[]](0xEF, 0xBB, 0xBF, 0x41, 0x3D, 0x31))
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -EnvFile $bom -WhatIf
    } -MessageLike "-EnvFile '*bom.env' starts with a UTF-8 byte-order mark*" `
        -Message '-WhatIf still refuses a dotenv file with a byte-order mark'
    Assert-Throws -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value 'x' -Environment 'prod' -Organization 'org' -WhatIf
    } -MessageLike '-Environment and -Organization cannot be used together:*' -Message 'and two scopes at once'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for a value and a dotenv file, each holding a sentinel
$sentinel = 'SENTINELzq9'
$folder = Join-Path ([IO.Path]::GetTempPath()) "env-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
$plain = Join-Path $folder 'plain.env'
Set-Content -LiteralPath $plain -Value "A=$sentinel"
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubVariable -Name 'V' -Value $sentinel -Environment 'prod' `
            -Repository "https://user:$sentinel@github.com/o/r" `
            -WhatIf
        Set-GitHubVariable -Name 'V' -Value $sentinel -Organization 'org' -Repos 'a', 'b' -WhatIf
        Set-GitHubVariable -EnvFile $plain -Organization 'org' -Visibility 'all' -WhatIf
        Set-GitHubVariable -EnvFile $plain -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Set variable" on target "o/r environment prod variable V".'
        'What if: Performing the operation "Set variable" on target "organization org variable V".'
        "What if: Performing the operation `"Set variables from $plain`" on target `"organization org`"."
        "What if: Performing the operation `"Set variables from $plain`" on target" +
        " `"the current directory's repository`"."
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message '-WhatIf names each variable, or the dotenv file, in its scope, the repository without the credential'
    Assert-Equal -Expected @() -Actual @($result.Messages | Where-Object { $_.Contains($sentinel) }) `
        -Message 'and no line holds the value, the file''s content, or the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two listed variables piped in
$fake = New-FakeGitHubCli
try {
    # Act
    $variables = @(
        [PSCustomObject]@{ Name = 'A'; Repository = 'o/r' }
        [PSCustomObject]@{ Name = 'B'; Organization = 'org'; Visibility = 'all' }
    )
    $result = Get-WhatIfOutput -ScriptBlock { $variables | Set-GitHubVariable -Value $sentinel -WhatIf }

    # Assert
    $expected = @(
        'What if: Performing the operation "Set variable" on target "o/r variable A".'
        'What if: Performing the operation "Set variable" on target "organization org variable B".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped variable gets its own line, where it was read from, and neither holds the value'
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
        Set-GitHubVariable -Environment 'e'
    }).AddArgument($repoRoot)
try {
    # Act / Assert
    Assert-Equal -Expected 'Value' -Actual (Get-Command Set-GitHubVariable).DefaultParameterSet `
        -Message 'A name and a value is the default way to set a variable'
    Assert-Throws -ScriptBlock {
        $shell.Invoke()
    } -MessageLike '*missing mandatory parameters: Name Value.*' `
        -Message 'A call with neither asks for -Name and -Value, not for a parameter set to be resolved'
}
finally {
    $shell.Dispose()
}

exit (Complete-TestRun)
