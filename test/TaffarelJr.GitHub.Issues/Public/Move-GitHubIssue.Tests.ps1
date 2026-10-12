#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubIssuesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Move-GitHubIssue -Issue 12 -DestinationRepository 'o/other' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'transfer', '12', 'o/other', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The issue and destination are positional and the source repository goes through --repo'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - several issues piped to the same destination
$fake = New-FakeGitHubCli
try {
    # Act
    @('1', '2') | Move-GitHubIssue -DestinationRepository 'o/other'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped issue is transferred in its own call'
    Assert-Equal -Expected @('issue', 'transfer', '2', 'o/other') -Actual $calls[1].Arguments `
        -Message 'The second piped issue goes to the same destination'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - destinations given as a repository object, with a host, with a port,
# and as URLs gh reads
$destination = [PSCustomObject]@{ Url = 'https://github.com/o/x'; NameWithOwner = 'o/x' }
$fake = New-FakeGitHubCli
try {
    # Act
    Move-GitHubIssue -Issue 12 -DestinationRepository $destination
    Move-GitHubIssue -Issue 13 -DestinationRepository 'ghe.example.com/o/x.git'
    Move-GitHubIssue -Issue 14 -DestinationRepository 'ghe.example.com:8443/o/x'
    Move-GitHubIssue -Issue 15 -DestinationRepository 'git+https://github.com/o/x.git'
    Move-GitHubIssue -Issue 16 -DestinationRepository 'git@github.com:o/x.git'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    $expected = @('issue', 'transfer', '12', 'https://github.com/o/x')
    Assert-Equal -Expected $expected -Actual $calls[0].Arguments `
        -Message 'A repository object is read by its Url, not by its text'
    $expected = @('issue', 'transfer', '13', 'ghe.example.com/o/x')
    Assert-Equal -Expected $expected -Actual $calls[1].Arguments `
        -Message 'HOST/OWNER/REPO is taken, without the .git gh would keep'
    $expected = @('issue', 'transfer', '14', 'ghe.example.com:8443/o/x')
    Assert-Equal -Expected $expected -Actual $calls[2].Arguments -Message 'HOST:PORT/OWNER/REPO is taken as it is'
    $expected = @('issue', 'transfer', '15', 'git+https://github.com/o/x.git')
    Assert-Equal -Expected $expected -Actual $calls[3].Arguments -Message 'and so is a URL in a scheme gh knows'
    $expected = @('issue', 'transfer', '16', 'git@github.com:o/x.git')
    Assert-Equal -Expected $expected -Actual $calls[4].Arguments -Message 'and the SSH form'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - destinations that name no one repository, one of them a gh option
$refused = @(
    @{ Given = '--web'; Message = 'A destination that is a gh option is refused' }
    @{ Given = '-Rx/y'; Message = 'as is one that would set --repo instead' }
    @{ Given = 'other'; Message = 'A destination without an owner is refused' }
    @{ Given = 'a/b/c/d'; Message = 'as is one with more parts than HOST/OWNER/REPO' }
    @{ Given = 'o/my repo'; Message = 'and one with a space in it' }
    @{ Given = 'r:x'; Message = 'A colon is no URL scheme gh knows' }
    @{ Given = 'host:o/x'; Message = 'and an owner cannot hold one' }
    @{ Given = 'HTTPS://github.com/o/x'; Message = 'gh reads a scheme only in lower case' }
)
$fake = New-FakeGitHubCli
try {
    foreach ($case in $refused) {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            Move-GitHubIssue -Issue 12 -DestinationRepository $case.Given
        } -MessageLike "'$($case.Given)' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL." `
            -Message $case.Message
    }

    Assert-Throws -ScriptBlock {
        Move-GitHubIssue -Issue 12 -DestinationRepository @('o/x', 'o/y')
    } -MessageLike 'Give one repository at a time for -DestinationRepository, not a list of 2; call once per repository.' `
        -Message 'Several destinations are refused'
    Assert-Throws -ScriptBlock {
        Move-GitHubIssue -Issue 12 -DestinationRepository @()
    } -MessageLike '-DestinationRepository is an empty list: give one repository, or leave it out.' `
        -Message 'An empty list names the parameter it was given to'
    Assert-Throws -ScriptBlock {
        Move-GitHubIssue -Issue 12 -DestinationRepository ' '
    } -MessageLike '-DestinationRepository is blank: give OWNER/REPO, HOST/OWNER/REPO, or a URL.' `
        -Message 'and a blank destination is called blank, not quoted as '''''
    Assert-Throws -ScriptBlock {
        Move-GitHubIssue -Issue 12 -DestinationRepository $null
    } -MessageLike '-DestinationRepository was given, but it is $null: give the repository to transfer the issue to.' `
        -Message 'A destination given as $null is refused with a sentence, not a binding error'
    Assert-Throws -ScriptBlock {
        @(1, 2) | Move-GitHubIssue -DestinationRepository @($null)
    } -MessageLike '-DestinationRepository was given, but it is $null: give the repository to transfer the issue to.' `
        -Message 'as is a list holding only $null'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a destination and a repository
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Move-GitHubIssue -Issue 12 -DestinationRepository 'o/other' -Repository 'o/r' -WhatIf
    }

    # Assert
    $expected = @('What if: Performing the operation "Transfer issue to o/other" on target "o/r issue #12".')
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names the issue and where it would go'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns nothing'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and transfers nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a destination given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Move-GitHubIssue -Issue 12 -DestinationRepository $null -WhatIf
    } -MessageLike '-DestinationRepository was given, but it is $null: give the repository to transfer the issue to.' `
        -Message '-WhatIf still refuses a destination given as $null'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two issues piped under -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        @('1', '2') | Move-GitHubIssue -DestinationRepository 'o/other' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Transfer issue to o/other" on target "issue #1".'
        'What if: Performing the operation "Transfer issue to o/other" on target "issue #2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each piped issue'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and transfers neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a credential in the destination's URL, given as text
# and as a repository object's Url
$fake = New-FakeGitHubCli
$url = 'https://user:SENTINEL@ghe.example.com/o/x.git'
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Move-GitHubIssue -Issue 1 -DestinationRepository $url -WhatIf
        Move-GitHubIssue -Issue 2 -DestinationRepository ([PSCustomObject]@{ Url = $url }) -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Transfer issue to ghe.example.com/o/x" on target "issue #1".'
        'What if: Performing the operation "Transfer issue to ghe.example.com/o/x" on target "issue #2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names the destination without the credential its URL carried'
    Assert-Equal -Expected 0 -Actual @($whatIf.Messages -match 'SENTINEL').Count -Message 'which no line holds'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and transfers nothing'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
