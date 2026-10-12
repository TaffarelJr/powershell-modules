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
# Arrange - the minimum: a name and a visibility
$fake = New-FakeGitHubCli -Output @('https://github.com/o/new')
try {
    # Act
    $url = New-GitHubRepository -Name 'o/new' -Visibility private
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'create', 'o/new', '--private') -Actual $call.Arguments `
        -Message 'The visibility becomes gh''s --public/--private/--internal flag'
    Assert-Equal -Expected 'https://github.com/o/new' -Actual $url -Message 'The new repository''s URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option, the visibility in mixed case, with clone chatter ahead of the URL
$fake = New-FakeGitHubCli -Output @('Cloning into ''new''...', 'https://github.com/o/new')
try {
    # Act
    $url = New-GitHubRepository -Name 'new' -Visibility 'Public' -Description 'd' -Homepage 'https://h' -AddReadme `
        -Gitignore 'VisualStudio' `
        -License 'mit' `
        -Template 'o/tpl' `
        -IncludeAllBranches `
        -DisableIssues `
        -DisableWiki `
        -Team 'devs' `
        -Source '.' `
        -RemoteName 'upstream' `
        -Push `
        -Clone
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'repo', 'create', 'new', '--public', '--description=d', '--homepage=https://h', '--add-readme',
            '--gitignore=VisualStudio', '--license=mit', '--template=o/tpl', '--include-all-branches',
            '--disable-issues', '--disable-wiki', '--team=devs', "--source=$((Get-Location).ProviderPath)",
            '--remote=upstream', '--push', '--clone'
        ) `
        -Actual $call.Arguments `
        -Message 'Each option becomes its gh flag, the visibility lower-cased, since gh''s flags are case-sensitive'
    Assert-Equal -Expected 'https://github.com/o/new' -Actual $url `
        -Message 'The URL is picked out from among other output lines'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the remote name given as -Remote, the word gh's own flag uses
$fake = New-FakeGitHubCli -Output @('https://github.com/o/new')
try {
    # Act
    New-GitHubRepository -Name 'new' -Visibility private -Source '.' -Remote 'upstream' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('repo', 'create', 'new', '--private', "--source=$((Get-Location).ProviderPath)", '--remote=upstream')
    Assert-Equal -Expected $expected -Actual $call.Arguments -Message '-Remote is an alias of -RemoteName'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a -Source written with ~ and one relative to PowerShell's location, which gh would read wrongly
$folder = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "repo-$([Guid]::NewGuid())")
$elsewhere = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "repo-$([Guid]::NewGuid())")
$fake = New-FakeGitHubCli -Output @('https://github.com/o/new')
try {
    # Act
    Use-SplitLocation -Location $folder.FullName -ProcessDirectory $elsewhere.FullName -ScriptBlock {
        New-GitHubRepository -Name 'new' -Visibility private -Source '~/x' | Out-Null
        New-GitHubRepository -Name 'new' -Visibility private -Source 'work' | Out-Null
    }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('repo', 'create', 'new', '--private', "--source=$(Join-Path $HOME 'x')") `
        -Actual $calls[0].Arguments `
        -Message 'A -Source with ~ is given to gh as the home folder it stands for, since gh expands no ~'
    Assert-Equal -Expected @('repo', 'create', 'new', '--private', "--source=$(Join-Path $folder.FullName 'work')") `
        -Actual $calls[1].Arguments `
        -Message 'and a relative -Source as the full path under PowerShell''s location, not the process''s'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if line for a -Source written with ~
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        New-GitHubRepository -Name 'new' -Visibility private -Source '~/x' -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Create private repository, adding it as a remote of' +
    " $(Join-Path $HOME 'x')`" on target `"new`"."
    Assert-Equal -Expected @($expected) -Actual $result.Messages `
        -Message '-WhatIf names the folder gh would be given, with ~ resolved'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a template given as a repository object, and options that start with a dash
$fake = New-FakeGitHubCli -Output @('https://github.com/o/new')
try {
    # Act
    $template = [PSCustomObject]@{ Url = 'https://github.com/o/t'; NameWithOwner = 'o/t' }
    New-GitHubRepository -Name 'new' -Visibility private -Template $template | Out-Null
    New-GitHubRepository -Name 'new' -Visibility private -License '-x' -Team '-y' | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('repo', 'create', 'new', '--private', '--template=https://github.com/o/t') `
        -Actual $calls[0].Arguments `
        -Message 'A template object is read by its Url, not sent as its text'
    Assert-Equal -Expected @('repo', 'create', 'new', '--private', '--license=-x', '--team=-y') `
        -Actual $calls[1].Arguments `
        -Message 'Free-text options travel joined to their flags, so a dash-leading one stays a value'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh printing no URL at all
$fake = New-FakeGitHubCli -Output @('nothing to see')
try {
    # Act
    $url = @(New-GitHubRepository -Name 'new' -Visibility private)

    # Assert
    Assert-Equal -Expected 0 -Actual $url.Count -Message 'No URL among the output returns nothing, not $null'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a name that looks like an option, blank options, and a template given as a list
$blankOptions = @(
    @{ Option = 'Gitignore'; What = 'a .gitignore template name' }
    @{ Option = 'License'; What = 'a license keyword' }
    @{ Option = 'Template'; What = 'OWNER/REPO, HOST/OWNER/REPO, or a URL' }
    @{ Option = 'Description'; What = 'a description' }
    @{ Option = 'Homepage'; What = 'a home page URL' }
    @{ Option = 'Team'; What = 'a team name' }
    @{ Option = 'Source'; What = 'a local repository folder' }
    @{ Option = 'RemoteName'; What = 'a remote name' }
)
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubRepository -Name '--source' -Visibility private
    } -MessageLike "*'--source' starts with '-', which gh would read as an option*" `
        -Message 'A name starting with a dash is refused'
    Assert-Throws -ScriptBlock {
        New-GitHubRepository -Name ' ' -Visibility private
    } -MessageLike "-Name is blank: give the new repository's name." -Message 'A blank name is refused, not sent to gh'
    foreach ($row in $blankOptions) {
        $blank = @{ $row.Option = ' ' }
        Assert-Throws -ScriptBlock {
            New-GitHubRepository -Name 'new' -Visibility private @blank
        } -MessageLike "-$($row.Option) is blank: give $($row.What), or leave it out." `
            -Message "A blank -$($row.Option) is refused, not dropped or sent"
    }

    Assert-Throws -ScriptBlock {
        New-GitHubRepository -Name 'new' -Visibility private -Template @('o/a', 'o/b')
    } -MessageLike 'Give one repository at a time for -Template, not a list of 2; call once per repository.' `
        -Message 'A list of templates gets Core''s repository message, naming -Template'
    Assert-Throws -ScriptBlock {
        New-GitHubRepository -Name 'new' -Visibility private -Template @()
    } -MessageLike '-Template is an empty list: give one repository, or leave it out.' `
        -Message 'and an empty list names -Template, not -Repository'
    Assert-Throws -ScriptBlock {
        New-GitHubRepository -Name 'new' -Visibility private -Template @($null)
    } -MessageLike '-Template is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL, or leave it out.' `
        -Message 'A list holding only $null is blank, as a filter that matched nothing gives, not a repository without a template'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf beside other parameters, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli -Output @('https://github.com/o/new')
try {
    # Act
    $out = @(New-GitHubRepository -Name 'new' -Visibility 'Private' -Description 'd' -AddReadme -Template 'o/t' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so no repository is created'
    Assert-Equal -Expected @() -Actual $out -Message 'and no URL is returned'

    # Act
    $url = New-GitHubRepository -Name 'new' -Visibility 'Private' -Description 'd' -AddReadme -Template 'o/t' `
        -WhatIf:$false `
        -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'create', 'new', '--private', '--description=d', '--add-readme', '--template=o/t') `
        -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false create as before, neither one reaching gh'
    Assert-Equal -Expected 'https://github.com/o/new' -Actual $url -Message 'and the URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a blank name
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        New-GitHubRepository -Name ' ' -Visibility private -WhatIf
    } -MessageLike "-Name is blank: give the new repository's name." -Message '-WhatIf still refuses a blank name'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines: each local change named, PowerShell's location apart from the process's
$folder = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "repo-$([Guid]::NewGuid())")
$elsewhere = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "repo-$([Guid]::NewGuid())")
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        Use-SplitLocation -Location $folder.FullName -ProcessDirectory $elsewhere.FullName -ScriptBlock {
            New-GitHubRepository -Name 'new' -Visibility 'Public' -Source 'work' -RemoteName 'up' -Push -WhatIf
            New-GitHubRepository -Name 'o/new' -Visibility 'private' -Source $elsewhere.FullName -WhatIf
            New-GitHubRepository -Name 'new' -Visibility 'internal' `
                -Template 'https://user:SENTINEL@github.com/o/t' `
                -Clone `
                -WhatIf
        }
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Create public repository, adding it as remote up of' +
        " $(Join-Path $folder.FullName 'work') and pushing the local commits to it`" on target `"new`"."
        'What if: Performing the operation "Create private repository, adding it as a remote of' +
        " $($elsewhere.FullName)`" on target `"o/new`"."
        'What if: Performing the operation "Create internal repository from template o/t, cloning it into a new' +
        " folder in $($folder.FullName)`" on target `"new`"."
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message ('-WhatIf names the remote added to -Source, resolved against PowerShell''s location, the push, the' +
            ' template without its credential, and the clone''s folder')
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder, $elsewhere -Recurse -Force
}

exit (Complete-TestRun)
