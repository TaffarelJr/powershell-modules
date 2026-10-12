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
# Arrange - one ruleset in full, from a named repository
$fake = New-FakeGitHubCli `
    -Output @('{"id":123,"name":"Main","enforcement":"active","conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"]}}}')
try {
    # Act
    $ruleset = Get-GitHubRuleset -Id 123 -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets/123') -Actual $call.Arguments `
        -Message 'A named repository is embedded directly in the endpoint path, not passed as --repo'
    Assert-Equal -Expected 'Main' -Actual $ruleset.Name `
        -Message 'The ruleset comes back as one object with PascalCase fields'
    Assert-Equal -Expected @('~DEFAULT_BRANCH') -Actual $ruleset.Conditions.RefName.Include `
        -Message 'Nested conditions are re-cased too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current directory's repository, via the ambient-repo placeholder
$fake = New-FakeGitHubCli -Output @('{"id":1}')
try {
    # Act
    Get-GitHubRuleset -Id 1 | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/{owner}/{repo}/rulesets/1') -Actual $call.Arguments `
        -Message 'Without -Repository, gh''s own {owner}/{repo} placeholder is used'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an enterprise repository, as an object and as text with -Hostname
$fake = New-FakeGitHubCli -Output @('{"id":1}')
try {
    # Act
    Get-GitHubRuleset -Id 1 -Repository ([PSCustomObject]@{
        Url = 'https://ghe.example.com/o/r'
        NameWithOwner = 'o/r'
    }) | Out-Null
    Get-GitHubRuleset -Id 1 -Repository 'o/r' -Hostname 'ghe.example.com' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets/1', '--hostname', 'ghe.example.com') `
        -Actual $calls[0].Arguments `
        -Message 'A repository object is read by its Url, and its host goes to gh as --hostname'
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets/1', '--hostname', 'ghe.example.com') `
        -Actual $calls[1].Arguments `
        -Message 'as does -Hostname beside OWNER/REPO'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing a repository's rulesets, including inherited ones
$fake = New-FakeGitHubCli -Output @('[[{"id":1,"name":"A"}],[{"id":2,"name":"B"}]]')
try {
    # Act
    $rulesets = Get-GitHubRuleset -List -IncludeParents -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets?per_page=100&includes_parents=true', '--paginate', '--slurp') `
        -Actual $call.Arguments `
        -Message '-IncludeParents adds the query string'
    Assert-Equal -Expected 2 -Actual $rulesets.Count -Message 'Every listed ruleset is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - organization-scoped, single listed ruleset
$fake = New-FakeGitHubCli -Output @('[[{"id":9}]]')
try {
    # Act
    $rulesets = Get-GitHubRuleset -List -Organization 'TaffarelJr'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'orgs/TaffarelJr/rulesets?per_page=100', '--paginate', '--slurp') `
        -Actual $call.Arguments `
        -Message '-Organization scopes to the org endpoint instead of a repository'
    Assert-That -Condition ($rulesets -isnot [array]) `
        -Message 'A single listed ruleset is written as that one object, not wrapped in an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - parents left out, and left to GitHub's default
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act
    Get-GitHubRuleset -List -IncludeParents:$false -Repository 'o/r' | Out-Null
    Get-GitHubRuleset -List -Repository 'o/r' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets?per_page=100&includes_parents=false', '--paginate', '--slurp') `
        -Actual $calls[0].Arguments `
        -Message '-IncludeParents:$false asks for them to be left out'
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets?per_page=100', '--paginate', '--slurp') `
        -Actual $calls[1].Arguments `
        -Message 'Without it, every page of a full page size is read and the default is GitHub''s'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - pages that hold more than one page's worth
$fake = New-FakeGitHubCli -Output @('[[{"id":1},{"id":2}],[{"id":3}]]')
try {
    # Act
    $rulesets = @(Get-GitHubRuleset -List -Repository 'o/r')

    # Assert
    Assert-Equal -Expected @([long]1, [long]2, [long]3) -Actual @($rulesets.ForEach('Id')) `
        -Message 'The pages come back as one flat list, so no ruleset past the first page is lost'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository's listing holding its own ruleset and one inherited from its organization
$listing = New-FakeGitHubCli `
    -Output @('[[{"id":1,"name":"Own","source_type":"Repository","source":"cli/cli"},{"id":2,"name":"Inherited","source_type":"Organization","source":"cli"}]]')
try {
    $listed = @(Get-GitHubRuleset -List -Repository 'cli/cli')
}
finally {
    Remove-FakeGitHubCli -Fixture $listing
}

$fake = New-FakeGitHubCli -Output @('{"id":1}')
try {
    # Act
    $listed | Get-GitHubRuleset | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('api', 'repos/cli/cli/rulesets/1') -Actual $calls[0].Arguments `
        -Message 'A piped ruleset is read by its Source: a repository''s from that repository, not the current one'
    Assert-Equal -Expected @('api', 'orgs/cli/rulesets/2') -Actual $calls[1].Arguments `
        -Message 'and an organization''s from that organization'
    Assert-That -Condition ($listed[0].PSObject.Properties.Name -notcontains 'Hostname') `
        -Message 'A listing from gh''s default host carries no Hostname'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a GitHub Enterprise listing holding a repository's, an enterprise's, and an organization's ruleset
$listing = New-FakeGitHubCli `
    -Output @('[[{"id":1,"source_type":"Repository","source":"o/r"},{"id":2,"source_type":"Enterprise","source":"ent"},{"id":3,"source_type":"Organization","source":"org"}]]')
try {
    $enterpriseListed = @(Get-GitHubRuleset -List -Repository 'ghe.example.com/o/r')
}
finally {
    Remove-FakeGitHubCli -Fixture $listing
}

$fake = New-FakeGitHubCli -Output @('{"id":1}')
try {
    # Act
    $warnings = @()
    $enterpriseListed | Get-GitHubRuleset -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('ghe.example.com', 'ghe.example.com', 'ghe.example.com') `
        -Actual @($enterpriseListed.ForEach('Hostname')) `
        -Message 'Each ruleset listed from an enterprise host carries that Hostname'
    Assert-Equal -Expected 2 -Actual $calls.Count `
        -Message 'The enterprise-level ruleset is skipped, and the pipe goes on to the next one'
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets/1', '--hostname', 'ghe.example.com') `
        -Actual $calls[0].Arguments `
        -Message 'A piped enterprise ruleset is read from its own host, not the default one'
    Assert-Equal -Expected @('api', 'orgs/org/rulesets/3', '--hostname', 'ghe.example.com') `
        -Actual $calls[1].Arguments `
        -Message 'an organization''s too'
    Assert-Equal -Expected @('Ruleset 2 is defined for the enterprise ent, which cannot be read here: skipped.') `
        -Actual @($warnings.ForEach('Message')) `
        -Message 'and the skipped one is named in a warning'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - piped rulesets beside a -Repository or -Organization naming their own place
$fake = New-FakeGitHubCli -Output @('{"id":1}')
try {
    # Act
    [PSCustomObject]@{
        Id = [long]1
        Source = 'a/b'
        SourceType = 'Repository'
        Hostname = 'ghe.io'
    } | Get-GitHubRuleset -Repository 'A/B' | Out-Null
    [PSCustomObject]@{
        Id = [long]2
        Source = 'org'
        SourceType = 'Organization'
    } | Get-GitHubRuleset -Organization 'ORG' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('api', 'repos/A/B/rulesets/1', '--hostname', 'ghe.io') -Actual $calls[0].Arguments `
        -Message 'A -Repository naming the ruleset''s own repository is read on the host it was listed from'
    Assert-Equal -Expected @('api', 'orgs/org/rulesets/2') -Actual $calls[1].Arguments `
        -Message 'and an -Organization naming its own organization, in any case, reads it there'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a piped or given Source that names another place than -Repository or -Organization, and one without a SourceType
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]1; Source = 'a/b'; SourceType = 'Repository' } | Get-GitHubRuleset `
            -Repository 'x/y'
    } -MessageLike 'Ruleset 1 is in a/b, but -Repository names x/y: give one or the other.' `
        -Message 'A piped ruleset from another repository than -Repository names is refused, not read from the wrong one'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]2; Source = 'org'; SourceType = 'Organization' } | Get-GitHubRuleset `
            -Repository 'x/y'
    } -MessageLike 'Ruleset 2 is in the organization org, but -Repository names x/y: give one or the other.' `
        -Message 'as is an organization''s ruleset beside a -Repository'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]1; Source = 'a/b'; SourceType = 'Repository' } | Get-GitHubRuleset `
            -Organization 'o2'
    } -MessageLike 'Ruleset 1 is in a/b, but -Organization names o2: give one or the other.' `
        -Message 'and a repository''s ruleset beside an -Organization'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]2; Source = 'org'; SourceType = 'Organization' } | Get-GitHubRuleset `
            -Organization 'o2'
    } -MessageLike 'Ruleset 2 is in org, but -Organization names o2: give one or the other.' `
        -Message 'and another organization''s ruleset'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]9; Source = 'a/b' } | Get-GitHubRuleset
    } -MessageLike '-Source works only with -SourceType: it does not say whether it names a repository or an organization. Give -SourceType too, or leave -Source off.' `
        -Message 'A Source without a SourceType is refused, not read from the current directory''s repository'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -Id 1 -Source 'a/b' -SourceType Repository -Repository 'x/y'
    } -MessageLike '-Source and -Repository cannot be used together: -Source already names where the ruleset is defined. Give only one.' `
        -Message 'and an explicit -Source beside -Repository'
    $sourceTypeAlone = '-SourceType works only with -Source: it says what kind of place -Source names. Give -Source too, or leave -SourceType off.'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]1; SourceType = 'Organization' } | Get-GitHubRuleset
    } -MessageLike $sourceTypeAlone `
        -Message 'A SourceType without a Source is refused, not read from the current directory''s repository'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -Id 1 -SourceType Organization
    } -MessageLike $sourceTypeAlone -Message 'as is an explicit one'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]1; SourceType = 'Organization' } | Get-GitHubRuleset -Organization 'org'
    } -MessageLike $sourceTypeAlone -Message 'and one beside -Organization, rather than a message with an empty name'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]1; SourceType = 'Repository' } | Get-GitHubRuleset -Repository 'x/y'
    } -MessageLike $sourceTypeAlone -Message 'and one beside -Repository, rather than a binder message'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]1; Source = ''; SourceType = 'Repository' } | Get-GitHubRuleset
    } -MessageLike $sourceTypeAlone -Message 'and a blank piped Source'
    $savedHost = $env:GH_HOST
    $env:GH_HOST = $null
    try {
        Assert-Throws -ScriptBlock {
            [PSCustomObject]@{
                Id = [long]1
                Source = 'a/b'
                SourceType = 'Repository'
                Hostname = $null
            } | Get-GitHubRuleset `
                -Repository 'ghe.io/a/b'
        } -MessageLike 'Ruleset 1 is in github.com/a/b, but -Repository names ghe.io/a/b: give one or the other.' `
            -Message 'A ruleset listed from the default host is refused beside another host, not read there'
    }
    finally {
        $env:GH_HOST = $savedHost
    }
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - piped rulesets whose Hostname is $null or empty, as a projected github.com listing gives
$fake = New-FakeGitHubCli -Output @('{"id":5}')
try {
    # Act
    [PSCustomObject]@{
        Id = [long]5
        Source = 'o/r'
        SourceType = 'Repository'
        Hostname = $null
    } | Get-GitHubRuleset | Out-Null
    [PSCustomObject]@{
        Id = [long]5
        Source = 'o/r'
        SourceType = 'Repository'
        Hostname = ''
    } | Get-GitHubRuleset | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @(@('api', 'repos/o/r/rulesets/5'), @('api', 'repos/o/r/rulesets/5')) `
        -Actual @($calls.ForEach({ , $_.Arguments })) `
        -Message 'A piped $null or empty Hostname means gh''s default host, not a refused one'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{
            Id = [long]5
            Source = 'o/r'
            SourceType = 'Repository'
            Hostname = 'ghe.example.com:8443'
        } | Get-GitHubRuleset
    } -MessageLike "'ghe.example.com:8443' is not a host name: give it bare*" `
        -Message 'while a piped host with a port is still refused'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}
#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that would change the endpoint's path, mixes that make no sense, and no repository
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -List -Repository 'o/r/../../orgs/x'
    } -MessageLike "*'o/r/../../orgs/x' is not a repository the API can be asked about*" `
        -Message 'A repository that is not OWNER/REPO is refused, so it cannot reach another endpoint'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -List -Organization 'org/rulesets/9'
    } -MessageLike "*'org/rulesets/9' is not an organization name*" `
        -Message 'as is an organization name that is not one'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]3; Source = 'org/rulesets/9'; SourceType = 'Organization' } | Get-GitHubRuleset
    } -MessageLike "'org/rulesets/9' is not an organization name: give letters, digits, and dashes." `
        -Message 'and a piped organization Source that is not one'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Id = [long]3; Source = 'x'; SourceType = 'Team' } | Get-GitHubRuleset
    } -MessageLike "*'Team' is not a ruleset source type: give Repository, Organization, or Enterprise." `
        -Message 'A source type GitHub does not have is refused'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -Id 1 -Hostname 'ghe.example.com:8443'
    } -MessageLike "*'ghe.example.com:8443' is not a host name: give it bare*" `
        -Message 'A host with a port is refused by Core''s host name check'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -Id 1 -Hostname ''
    } -MessageLike "*'' is not a host name*" -Message 'as is an empty one'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -Id 0
    } -MessageLike "*'Id'*minimum allowed range of 1*" -Message 'A ruleset id below 1 is refused'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -List -Organization 'org' -Repository 'o/r'
    } -MessageLike '-Organization and -Repository cannot be used together: a ruleset is read from one place - an organization or a repository. Give only one.' `
        -Message 'An organization and a repository together are refused, saying why'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -Id 1 -Organization ''
    } -MessageLike "*'' is not an organization name: give letters, digits, and dashes." `
        -Message 'An empty organization gets the organization name rule''s message'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -List -Organization 'org' -IncludeParents
    } -MessageLike '*Parameter set cannot be resolved*' `
        -Message '-IncludeParents is refused for an organization, which has no parents'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -Id 1 -Repository 'ghe.example.com/o/r' -Hostname 'github.com'
    } -MessageLike "*'ghe.example.com/o/r' is on ghe.example.com, but -Hostname names github.com*" `
        -Message 'A host that disagrees with -Hostname is refused'
    Assert-Throws -ScriptBlock {
        Get-GitHubRuleset -Id 1 -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of reading the current directory''s'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare call, run with no host so a missing mandatory parameter fails instead of asking for it
$shell = [PowerShell]::Create()
$null = $shell.AddScript({
        param($Root)

        $ErrorActionPreference = 'Stop'
        Import-Module (Join-Path $Root 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1')
        Import-Module (Join-Path $Root 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1')
        Import-Module (Join-Path $Root 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1')
        Get-GitHubRuleset
    }).AddArgument($repoRoot)
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        $shell.Invoke()
    } -MessageLike '*missing mandatory parameters: Id*' `
        -Message 'A bare call names the missing -Id, not an unresolved parameter set'
}
finally {
    $shell.Dispose()
}

exit (Complete-TestRun)
