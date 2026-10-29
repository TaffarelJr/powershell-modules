#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter',
    '',
    Justification = 'Read by the script blocks the tables hand to Assert-Throws, by scope.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case. <any> stands for text a case cannot know, such as a path.
$url = 'https://user:SENTINEL@ghe.example.com/o/r'
$shown = 'https://***@ghe.example.com/o/r'
$pattern = {
    param([string]$Text)

    (($Text -split '<any>') | ForEach-Object { [WildcardPattern]::Escape($_) }) -join '*'
}
$assertMessage = {
    param([scriptblock]$Block, [string]$Expected, [string]$Name)

    Assert-Throws -ScriptBlock $Block -MessageLike (& $pattern $Expected) -Message $Name
}
$newWork = {
    $folder = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "credential-$([Guid]::NewGuid())")
    $elsewhere = New-Item -ItemType Directory -Path (Join-Path $folder 'elsewhere')
    $named = New-Item -ItemType Directory -Path (Join-Path $folder 'SENTINEL@h.example')
    $utf8 = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText((Join-Path $folder 'key.pub'), "ssh-ed25519 AAAA test`n", $utf8)
    [IO.File]::WriteAllText((Join-Path $named 'key.pub'), "ssh-ed25519 AAAA test`n", $utf8)
    [IO.File]::WriteAllText((Join-Path $named 'a.env'), "A=1`n", $utf8)
    [IO.File]::WriteAllBytes((Join-Path $named 'bom.env'), [byte[]](0xEF, 0xBB, 0xBF) + $utf8.GetBytes("A=1`n"))
    [IO.File]::WriteAllText((Join-Path $named 'utf16.env'), "A=1`n", [Text.UnicodeEncoding]::new($false, $true))

    [PSCustomObject]@{
        Folder    = $folder.FullName
        Elsewhere = $elsewhere.FullName
        Key       = Join-Path $folder 'key.pub'
    }
}
$notRepository = "'***@ghe.example.com:o/r' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
$notHost = "'***@ghe.example.com' is not a host name: give it bare, such as github.com - labels of letters," +
' digits, dashes, and underscores joined by single dots, none starting or ending with a dash, and no' +
' scheme, port, path, space, or trailing dot - or leave -Hostname out for the default host.'
$organizationUrl = 'https://user:SENTINEL@github.com/org'
$notOrganization = "'https://***@github.com/org' is not an organization name: give letters, digits, and dashes."
$notSecret = "'***@h' is not a secret name: give letters, digits, and _, not led by a digit or GITHUB_."
$notVariable = "'***@h' is not a variable name: give letters, digits, and _, not led by a digit or GITHUB_."
$option = "'-$shown' starts with '-', which gh would read as an option."

$savedHost = $env:GH_HOST
$env:GH_HOST = $null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - every message that shows a value it was given, with no gh run
    $messages = @(
        @{
            Block = { Get-GitHubLabel -Repository 'user:SENTINEL@ghe.example.com:o/r' }
            Expected = $notRepository
            Name = 'A -Repository that is not a repository, through Resolve-GitHubRepositoryArgument'
        }
        @{
            Block = { Remove-GitHubRepository -Repository "$url x" }
            Expected = "'$shown x' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
            Name = 'Remove-GitHubRepository, for text holding a space'
        }
        @{
            Block = { Copy-GitHubLabel -Source 'user:SENTINEL@ghe.example.com:o/r' }
            Expected = $notRepository
            Name = 'Copy-GitHubLabel, for -Source'
        }
        @{
            Block = { Rename-GitHubRepository -Repository 'user:SENTINEL@ghe.example.com:o/r' -NewName 'x' }
            Expected = $notRepository
            Name = 'Rename-GitHubRepository'
        }
        @{
            Block = { Set-GitHubDefaultRepository -Repository 'user:SENTINEL@ghe.example.com:o/r' }
            Expected = $notRepository
            Name = 'Set-GitHubDefaultRepository'
        }
        @{
            Block = { New-GitHubRepository -Name 'n' -Visibility private -Template 'user:SENTINEL@ghe.example.com:o/r' }
            Expected = $notRepository
            Name = 'New-GitHubRepository, for -Template'
        }
        @{
            Block = { Get-GitHubRuleset -Id 1 -Hostname 'user:SENTINEL@ghe.example.com' }
            Expected = $notHost
            Name = 'Get-GitHubRuleset, for -Hostname'
        }
        @{
            Block = { Get-GitHubRulesetCheck -Branch 'main' -Hostname 'user:SENTINEL@ghe.example.com' }
            Expected = "Cannot validate argument on parameter 'Hostname'. $notHost"
            Name = 'Get-GitHubRulesetCheck, for -Hostname'
        }
        @{
            Block = { Add-GitHubDeployKey -KeyFile 'SENTINEL@h.example/missing.pub' }
            Expected = "-KeyFile '***@h.example/missing.pub' is not a file."
            Name = 'Add-GitHubDeployKey, for -KeyFile'
        }
        @{
            Block = { Set-GitHubSecret -EnvFile 'SENTINEL@h.example/missing.env' }
            Expected = "-EnvFile '***@h.example/missing.env' is not a file."
            Name = 'Set-GitHubSecret, for -EnvFile'
        }
        @{
            Block = { Get-GitHubRulesetCheck -Branch 'main' -Repository $url }
            Expected = "'$shown' is not a repository the API can be asked about: give OWNER/REPO, HOST/OWNER/REPO," +
            ' or https://HOST/OWNER/REPO.'
            Name = 'ConvertTo-GitHubApiRepository, for a repository it cannot read'
        }
        @{
            Block = { Remove-GitHubLabel -Name "$url/issues/1" }
            Expected = "'$shown/issues/1' is not a label: a URL must end in /OWNER/REPO/labels/NAME."
            Name = 'ConvertTo-GitHubLabelReference, for a URL that names no label'
        }
        @{
            Block = { Remove-GitHubLabel -Name ([PSCustomObject]@{ Name = 'user:SENTINEL@h' }) }
            Expected = "The label '***@h' is an object with no Url, so it does not say its repository: give -Repository."
            Name = 'and for a label object with no Url'
        }
        @{
            Block = {
                Remove-GitHubLabel -Name "$url/labels/b" -Repository 'https://v:SENTINEL@ghe.example.com/o/other'
            }
            Expected = "'$shown/labels/b' is in ghe.example.com/o/r, but -Repository names" +
            ' https://***@ghe.example.com/o/other: give one or the other.'
            Name = 'and for a label from another repository'
        }
        @{
            Block = { New-GitHubLabel -Name 'user:SENTINEL@h' -Force }
            Expected = "-Force works only with -Color: without one gh would recolor an existing '***@h' at random." +
            ' Give -Color too, or leave -Force off.'
            Name = 'New-GitHubLabel, for the name'
        }
        @{
            Block = {
                [PSCustomObject]@{ Id = 5; Source = 'user:SENTINEL@h'; SourceType = 'Repository' } |
                    Get-GitHubRuleset -Organization 'org'
            }
            Expected = 'Ruleset 5 is in ***@h, but -Organization names org: give one or the other.'
            Name = 'Get-GitHubRuleset, for a Source beside -Organization'
        }
        @{
            Block = {
                [PSCustomObject]@{ Id = 5; Source = 'user:SENTINEL@h'; SourceType = 'Organization' } |
                    Get-GitHubRuleset -Repository $url
            }
            Expected = "Ruleset 5 is in the organization ***@h, but -Repository names ${shown}: give one or the other."
            Name = 'for an organization Source beside -Repository'
        }
        @{
            Block = {
                [PSCustomObject]@{ Id = 5; Source = 'o/r'; SourceType = 'Repository' } |
                    Get-GitHubRuleset -Repository 'https://v:SENTINEL@ghe.example.com/o/other'
            }
            Expected = 'Ruleset 5 is in o/r, but -Repository names https://***@ghe.example.com/o/other:' +
            ' give one or the other.'
            Name = 'for a repository Source naming another repository than -Repository'
        }
        @{
            Block = {
                [PSCustomObject]@{ Id = 5; Source = 'user:SENTINEL@h/o/r'; SourceType = 'Repository' } |
                    Get-GitHubRuleset -Repository $url
            }
            Expected = "Ruleset 5 is in github.com/***@h/o/r, but -Repository names ${shown}: give one or the other."
            Name = 'for a repository Source on another host than -Repository'
        }
        @{
            Block = {
                [PSCustomObject]@{ Id = 5; Source = 'user:SENTINEL@h'; SourceType = 'Organization' } | Get-GitHubRuleset
            }
            Expected = "'***@h' is not an organization name: give letters, digits, and dashes."
            Name = 'for an organization Source that is not an organization name'
        }
        @{
            Block = {
                [PSCustomObject]@{ Name = 'A'; Repository = $null } | Remove-GitHubSecret -Repository $url
            }
            Expected = "Secret A was listed from the current directory's repository, but -Repository names ${shown}:" +
            ' leave -Repository off, or list the secret with -Repository.'
            Name = 'Resolve-GitHubSecretScope, for a secret listed from the current directory'
        }
        @{
            Block = {
                [PSCustomObject]@{ Name = 'A'; Repository = 'o/r' } |
                    Remove-GitHubSecret -Repository 'https://v:SENTINEL@ghe.example.com/o/other'
            }
            Expected = 'Secret A is in o/r, but -Repository names https://***@ghe.example.com/o/other:' +
            ' give one or the other.'
            Name = 'for a secret from another repository'
        }
        @{
            Block = { [PSCustomObject]@{ Name = 'A'; Repository = 'o/r' } | Remove-GitHubSecret -Repository $url }
            Expected = "Secret A is in github.com/o/r, but -Repository names ${shown}: give one or the other."
            Name = 'for a secret from another host'
        }
        @{
            Block = {
                [PSCustomObject]@{ Name = 'A'; Repository = 'SENTINEL@h.example/o/r' } |
                    Remove-GitHubSecret -Repository $url
            }
            Expected = "Secret A is in ***@h.example/o/r, but -Repository names ${shown}: give one or the other."
            Name = 'for a secret whose repository carries a credential'
        }
        @{
            Block = {
                [PSCustomObject]@{ Name = 'A'; Repository = 'o/r'; Application = 'user:SENTINEL@h' } |
                    Remove-GitHubSecret -Application actions
            }
            Expected = 'Secret A is in the ***@h store, but -Application names actions: give one or the other.'
            Name = 'for a piped Application beside -Application'
        }
        @{
            Block = {
                [PSCustomObject]@{ Name = 'A'; Environment = 'user:SENTINEL@h' } |
                    Remove-GitHubSecret -Environment 'other'
            }
            Expected = 'Secret A is in environment ***@h, but -Environment names other: give one or the other.'
            Name = 'for a piped Environment beside -Environment'
        }
        @{
            Block = {
                [PSCustomObject]@{ Name = 'A'; Environment = 'prod' } |
                    Remove-GitHubSecret -Environment 'user:SENTINEL@h'
            }
            Expected = 'Secret A is in environment prod, but -Environment names ***@h: give one or the other.'
            Name = 'and for the -Environment given'
        }
        @{
            Block = {
                [PSCustomObject]@{ Id = [long]7; Repository = $null } | Remove-GitHubDeployKey -Repository $url
            }
            Expected = "Deploy key 7 was listed from the current directory's repository, but -Repository names" +
            " ${shown}: leave -Repository off, or list the key with -Repository."
            Name = 'Remove-GitHubDeployKey, for a key listed from the current directory'
        }
        @{
            Block = {
                [PSCustomObject]@{ Id = [long]7; Repository = 'o/r' } |
                    Remove-GitHubDeployKey -Repository 'https://v:SENTINEL@ghe.example.com/o/other'
            }
            Expected = 'Deploy key 7 is in o/r, but -Repository names https://***@ghe.example.com/o/other:' +
            ' give one or the other.'
            Name = 'for a key from another repository'
        }
        @{
            Block = {
                [PSCustomObject]@{ Id = [long]7; Repository = 'o/r' } | Remove-GitHubDeployKey -Repository $url
            }
            Expected = "Deploy key 7 is in github.com/o/r, but -Repository names ${shown}: give one or the other."
            Name = 'for a key from another host'
        }
        @{
            Block = {
                [PSCustomObject]@{ Id = [long]7; Repository = 'SENTINEL@h.example/o/r' } |
                    Remove-GitHubDeployKey -Repository $url
            }
            Expected = "Deploy key 7 is in ***@h.example/o/r, but -Repository names ${shown}: give one or the other."
            Name = 'for a key whose repository carries a credential'
        }
        @{
            Block = { Get-GitHubRuleset -List -Organization $organizationUrl }
            Expected = "Cannot validate argument on parameter 'Organization'. $notOrganization"
            Name = 'Get-GitHubRuleset, for -Organization'
        }
        @{
            Block = { Get-GitHubSecret -Organization $organizationUrl }
            Expected = "Cannot validate argument on parameter 'Organization'. $notOrganization"
            Name = 'Get-GitHubSecret, for -Organization'
        }
        @{
            Block = { Get-GitHubVariable -Organization $organizationUrl }
            Expected = "Cannot validate argument on parameter 'Organization'. $notOrganization"
            Name = 'Get-GitHubVariable, for -Organization'
        }
        @{
            Block = { New-GitHubFork -Organization $organizationUrl }
            Expected = "Cannot validate argument on parameter 'Organization'. $notOrganization"
            Name = 'New-GitHubFork, for -Organization'
        }
        @{
            Block = { Remove-GitHubSecret -Name 'A' -Organization $organizationUrl }
            Expected = "Cannot validate argument on parameter 'Organization'. $notOrganization"
            Name = 'Remove-GitHubSecret, for -Organization'
        }
        @{
            Block = { Remove-GitHubVariable -Name 'A' -Organization $organizationUrl }
            Expected = "Cannot validate argument on parameter 'Organization'. $notOrganization"
            Name = 'Remove-GitHubVariable, for -Organization'
        }
        @{
            Block = { Set-GitHubSecret -Name 'A' -Value 'v' -Organization $organizationUrl }
            Expected = "Cannot validate argument on parameter 'Organization'. $notOrganization"
            Name = 'Set-GitHubSecret, for -Organization'
        }
        @{
            Block = { Set-GitHubVariable -Name 'A' -Value 'v' -Organization $organizationUrl }
            Expected = "Cannot validate argument on parameter 'Organization'. $notOrganization"
            Name = 'Set-GitHubVariable, for -Organization'
        }
        @{
            Block = { Remove-GitHubSecret -Name 'user:SENTINEL@h' }
            Expected = "Cannot validate argument on parameter 'Name'. $notSecret"
            Name = 'Remove-GitHubSecret, for -Name'
        }
        @{
            Block = { Set-GitHubSecret -Name 'user:SENTINEL@h' -Value 'v' }
            Expected = "Cannot validate argument on parameter 'Name'. $notSecret"
            Name = 'Set-GitHubSecret, for -Name'
        }
        @{
            Block = { Remove-GitHubVariable -Name 'user:SENTINEL@h' }
            Expected = "Cannot validate argument on parameter 'Name'. $notVariable"
            Name = 'Remove-GitHubVariable, for -Name'
        }
        @{
            Block = { Set-GitHubVariable -Name 'user:SENTINEL@h' -Value 'v' }
            Expected = "Cannot validate argument on parameter 'Name'. $notVariable"
            Name = 'Set-GitHubVariable, for -Name'
        }
        @{
            Block = { Get-GitHubRepository -List -Owner "-$url" }
            Expected = "Cannot validate argument on parameter 'Owner'. $option"
            Name = 'Get-GitHubRepository, for -Owner'
        }
        @{
            Block = { New-GitHubRepository -Name "-$url" -Visibility private }
            Expected = "Cannot validate argument on parameter 'Name'. $option"
            Name = 'New-GitHubRepository, for -Name'
        }
        @{
            Block = { Rename-GitHubRepository -Repository 'o/r' -NewName "-$url" }
            Expected = "Cannot validate argument on parameter 'NewName'. $option"
            Name = 'Rename-GitHubRepository, for -NewName'
        }
    )

    # Act / Assert
    foreach ($case in $messages) {
        & $assertMessage $case.Block $case.Expected "$($case.Name) shows no credential"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - the warning for a ruleset of an enterprise, which is skipped
    $warnings = @(
        Get-WarningOutput -ScriptBlock {
            [PSCustomObject]@{ Id = 5; Source = 'user:SENTINEL@h'; SourceType = 'Enterprise' } | Get-GitHubRuleset
        }
    )
    Assert-Equal -Expected @('Ruleset 5 is defined for the enterprise ***@h, which cannot be read here: skipped.') `
        -Actual $warnings `
        -Message 'Get-GitHubRuleset warns without the credential its Source carried'
}
finally {
    $env:GH_HOST = $savedHost
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - files in a folder named like a credential, given by a relative path
$work = & $newWork
try {
    $files = @(
        @{
            Path = 'SENTINEL@h.example/bom.env'
            Expected = "-EnvFile '***@h.example/bom.env' starts with a UTF-8 byte-order mark, which gh reads as part" +
            ' of the first name: save the file without one.'
            Name = 'Resolve-GitHubEnvFile, for a UTF-8 byte-order mark'
        }
        @{
            Path = 'SENTINEL@h.example/utf16.env'
            Expected = "-EnvFile '***@h.example/utf16.env' starts with a UTF-16 byte-order mark, and gh reads only" +
            ' UTF-8: save the file as UTF-8 without a byte-order mark.'
            Name = 'and for a UTF-16 one'
        }
    )

    # Act / Assert
    foreach ($case in $files) {
        & $assertMessage {
            Use-SplitLocation -Location $work.Folder -ProcessDirectory $work.Elsewhere -ScriptBlock {
                Set-GitHubVariable -EnvFile $case.Path
            }
        } $case.Expected "$($case.Name) shows no credential"
    }
}
finally {
    Remove-Item -LiteralPath $work.Folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines of every change that names a value it was given
$work = & $newWork
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Use-SplitLocation -Location $work.Folder -ProcessDirectory $work.Elsewhere -ScriptBlock {
            Add-GitHubDeployKey -KeyFile 'SENTINEL@h.example/key.pub' -WhatIf
            Set-GitHubSecret -EnvFile 'SENTINEL@h.example/a.env' -WhatIf
            Set-GitHubVariable -EnvFile 'SENTINEL@h.example/a.env' -WhatIf
            New-GitHubFork -Remote -RemoteName 'user:SENTINEL@h' -ForkName 'user:SENTINEL@h2' -WhatIf
            New-GitHubRepository -Name 'user:SENTINEL@h' -Visibility private -RemoteName 'user:SENTINEL@h2' `
                -Source 'SENTINEL@h.example/src' `
                -WhatIf
            Sync-GitHubRepository -Branch 'user:SENTINEL@h' -WhatIf
            Remove-GitHubLabel -Name 'user:SENTINEL@h' -WhatIf
            Set-GitHubLabel -Name 'user:SENTINEL@h' -Color 'AABBCC' -WhatIf
            New-GitHubLabel -Name 'user:SENTINEL@h' -WhatIf
            Rename-GitHubRepository -Repository 'o/r' -NewName 'user:SENTINEL@h' -WhatIf
            Remove-GitHubSecret -Name 'A' -Environment 'user:SENTINEL@h' -WhatIf
            Set-GitHubVariable -Name 'A' -Value 'v' -Environment 'user:SENTINEL@h' -WhatIf
            Set-GitHubSecret -Name 'A' -Value 'v' -Repository $url -WhatIf
            Set-GitHubVariable -Name 'A' -Value 'v' -Repository $url -WhatIf
        }
    }

    # Assert
    $source = [IO.Path]::GetFullPath('***@h.example/src', $work.Folder)
    $expected = @(
        'What if: Performing the operation "Add deploy key from ***@h.example/key.pub" on target "the current' +
        " directory's repository`"."
        'What if: Performing the operation "Set secrets from ***@h.example/a.env" on target "the current' +
        " directory's repository`"."
        'What if: Performing the operation "Set variables from ***@h.example/a.env" on target "the current' +
        " directory's repository`"."
        'What if: Performing the operation "Fork repository as ***@h2, adding it as remote ***@h of' +
        " $($work.Folder)`" on target `"the current directory's repository`"."
        'What if: Performing the operation "Create private repository, adding it as remote ***@h2 of' +
        " $source`" on target `"***@h`"."
        "What if: Performing the operation `"Sync branch ***@h`" on target `"$($work.Folder)`"."
        'What if: Performing the operation "Delete label" on target "label ***@h".'
        'What if: Performing the operation "Edit label" on target "label ***@h".'
        'What if: Performing the operation "Create label" on target "label ***@h".'
        'What if: Performing the operation "Rename repository to ***@h" on target "o/r".'
        'What if: Performing the operation "Delete secret" on target "environment ***@h secret A".'
        'What if: Performing the operation "Set variable" on target "environment ***@h variable A".'
        'What if: Performing the operation "Set secret" on target "ghe.example.com/o/r secret A".'
        'What if: Performing the operation "Set variable" on target "ghe.example.com/o/r variable A".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each -WhatIf line shows no credential in a path, a name, an environment, or a repository'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $work.Folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a listing from a repository given as a URL that carries a credential
$fake = New-FakeGitHubCli -Output @('[{"id":1,"name":"A","title":"t"}]')
try {
    # Act
    $secret = Get-GitHubSecret -Repository $url
    $variable = Get-GitHubVariable -Repository $url
    $key = Get-GitHubDeployKey -Repository $url
    $result = Get-WhatIfOutput -ScriptBlock {
        $secret | Remove-GitHubSecret -WhatIf
        $variable | Remove-GitHubVariable -WhatIf
        $key | Remove-GitHubDeployKey -WhatIf
    }

    # Assert
    Assert-Equal -Expected $shown -Actual $secret.Repository `
        -Message 'A listed secret says where it was listed from without the credential'
    Assert-Equal -Expected $shown -Actual $variable.Repository -Message 'as does a variable'
    Assert-Equal -Expected $shown -Actual $key.Repository -Message 'and a deploy key'
    Assert-Equal -Expected @(
        'What if: Performing the operation "Delete secret" on target "ghe.example.com/o/r actions secret A".'
        'What if: Performing the operation "Delete variable" on target "ghe.example.com/o/r variable A".'
        'What if: Performing the operation "Delete deploy key" on target "ghe.example.com/o/r deploy key 1".'
    ) -Actual $result.Messages -Message 'and each is still acted on in the repository it was listed from'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails, echoing the URL on stderr
$work = & $newWork
$fake = New-FakeGitHubCli -ErrorOutput @("fatal: unable to access '$url/': HTTP 403") -ExitCode 1
try {
    $fail = {
        param([string]$Activity, [string]$Words)

        "$Activity failed: gh $Words (exit 1)`nfatal: unable to access '$shown/': HTTP 403"
    }
    $failures = @(
        @{
            Block = { Add-GitHubDeployKey -KeyFile $work.Key -Repository $url }
            Expected = & $fail 'Adding deploy key <any>' "repo deploy-key add <any> --repo $shown"
            Name = 'Add-GitHubDeployKey'
        }
        @{
            Block = { Copy-GitHubLabel -Source $url -Repository $url }
            Expected = & $fail "Copying labels from $shown" "label clone $shown --repo $shown"
            Name = 'Copy-GitHubLabel'
        }
        @{
            Block = { Get-GitHubDefaultRepository }
            Expected = & $fail 'Reading the default repository' 'repo set-default --view'
            Name = 'Get-GitHubDefaultRepository'
        }
        @{
            Block = { Get-GitHubDeployKey -Repository $url }
            Expected = & $fail 'Listing deploy keys' "repo deploy-key list --json <any> --repo $shown"
            Name = 'Get-GitHubDeployKey'
        }
        @{
            Block = { Get-GitHubLabel -Repository $url }
            Expected = & $fail 'Listing labels' "label list --json <any> --repo $shown"
            Name = 'Get-GitHubLabel'
        }
        @{
            Block = { Get-GitHubRepository -Repository $url }
            Expected = & $fail "Reading repository $shown" "repo view $shown --json <any>"
            Name = 'Get-GitHubRepository'
        }
        @{
            Block = { Get-GitHubRuleset -Id 5 -Repository 'ghe.example.com/o/r' }
            Expected = & $fail 'Calling repos/o/r/rulesets/5' 'api repos/o/r/rulesets/5<any>'
            Name = 'Get-GitHubRuleset'
        }
        @{
            Block = { Get-GitHubRulesetCheck -Branch 'main' -Repository 'ghe.example.com/o/r' }
            Expected = & $fail 'Calling repos/o/r/rules/branches/main?per_page=100' `
                'api repos/o/r/rules/branches/main?per_page=100<any>'
            Name = 'Get-GitHubRulesetCheck'
        }
        @{
            Block = { Get-GitHubSecret -Repository $url }
            Expected = & $fail 'Listing secrets' "secret list --json <any> --repo $shown"
            Name = 'Get-GitHubSecret'
        }
        @{
            Block = { Get-GitHubVariable -Name 'A' -Repository $url }
            Expected = & $fail 'Reading variable A' "variable get --json <any> --repo $shown -- A"
            Name = 'Get-GitHubVariable'
        }
        @{
            Block = { New-GitHubFork -Repository $url }
            Expected = & $fail "Forking repository $shown" "repo fork $shown --clone=false"
            Name = 'New-GitHubFork'
        }
        @{
            Block = { New-GitHubLabel -Name 'bug' -Repository $url }
            Expected = & $fail 'Creating label bug' "label create --repo $shown -- bug"
            Name = 'New-GitHubLabel'
        }
        @{
            Block = { New-GitHubRepository -Name 'n' -Visibility private -Template $url }
            Expected = & $fail 'Creating repository n' "repo create n --private --template=$shown"
            Name = 'New-GitHubRepository'
        }
        @{
            Block = { Remove-GitHubDeployKey -Id 7 -Repository $url }
            Expected = & $fail 'Deleting deploy key 7' "repo deploy-key delete 7 --repo $shown"
            Name = 'Remove-GitHubDeployKey'
        }
        @{
            Block = { Remove-GitHubLabel -Name 'bug' -Repository $url }
            Expected = & $fail 'Deleting label bug' "label delete --yes --repo $shown -- bug"
            Name = 'Remove-GitHubLabel'
        }
        @{
            Block = { Remove-GitHubRepository -Repository $url }
            Expected = & $fail "Deleting repository $shown" "repo delete $shown --yes"
            Name = 'Remove-GitHubRepository'
        }
        @{
            Block = { Remove-GitHubSecret -Name 'A' -Repository $url }
            Expected = & $fail 'Deleting secret A' "secret delete --repo $shown -- A"
            Name = 'Remove-GitHubSecret'
        }
        @{
            Block = { Remove-GitHubVariable -Name 'A' -Repository $url }
            Expected = & $fail 'Deleting variable A' "variable delete --repo $shown -- A"
            Name = 'Remove-GitHubVariable'
        }
        @{
            Block = { Rename-GitHubRepository -Repository $url -NewName 'x' }
            Expected = & $fail "Renaming $shown to x" "repo rename x --yes --repo $shown"
            Name = 'Rename-GitHubRepository'
        }
        @{
            Block = { Set-GitHubDefaultRepository -Repository $url }
            Expected = & $fail 'Setting the default repository' "repo set-default $shown"
            Name = 'Set-GitHubDefaultRepository'
        }
        @{
            Block = { Set-GitHubLabel -Name 'bug' -NewName 'x' -Repository $url }
            Expected = & $fail 'Editing label bug' "label edit --name=x --repo $shown -- bug"
            Name = 'Set-GitHubLabel'
        }
        @{
            Block = { Set-GitHubRepository -Repository $url -DefaultBranch 'main' }
            Expected = & $fail "Editing repository $shown" "repo edit $shown --default-branch=main"
            Name = 'Set-GitHubRepository'
        }
        @{
            Block = { Set-GitHubSecret -Name 'A' -Value 'v' -Repository $url }
            Expected = & $fail 'Setting secret A' "secret set --repo $shown -- A"
            Name = 'Set-GitHubSecret'
        }
        @{
            Block = { Set-GitHubVariable -Name 'A' -Value 'v' -Repository $url }
            Expected = & $fail 'Setting variable A' "variable set --repo $shown -- A"
            Name = 'Set-GitHubVariable'
        }
        @{
            Block = { Sync-GitHubRepository -Destination $url -Source $url }
            Expected = & $fail "Syncing repository $shown" "repo sync $shown --source $shown"
            Name = 'Sync-GitHubRepository'
        }
    )

    # Act / Assert
    foreach ($case in $failures) {
        & $assertMessage $case.Block $case.Expected "$($case.Name) shows no credential when gh fails"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $work.Folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that answers with something that is not JSON
$fake = New-FakeGitHubCli -Output @("moved to $url")
try {
    # Act / Assert
    & $assertMessage {
        Get-GitHubLabel -Repository 'o/r'
    } "gh's output is not valid JSON, starting 'moved to ${shown}': <any>" `
        'Get-GitHubLabel shows no credential in output that is not JSON'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
