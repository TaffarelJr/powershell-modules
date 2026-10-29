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
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubLabel -Name 'bug' -NewName 'defect' -Color 'FF0000' -Description 'Something broke' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'label', 'edit', '--name=defect', '--color=FF0000', '--description=Something broke', '--repo', 'o/r', '--',
            'bug'
        ) `
        -Actual $call.Arguments `
        -Message 'The current name is an operand and each change becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - only the color, and a label name that looks like an option
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubLabel -Name 'bug' -Color '00FF00'
    Set-GitHubLabel -Name '--name' -Color '000000'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('label', 'edit', '--color=00FF00', '--', 'bug') -Actual $calls[0].Arguments `
        -Message 'An omitted property is left alone'
    Assert-Equal -Expected @('label', 'edit', '--color=000000', '--', '--name') -Actual $calls[1].Arguments `
        -Message 'A name is an operand whatever it starts with, so it cannot turn into --name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - labels listed from another repository, as Get-GitHubLabel returns them
$listing = New-FakeGitHubCli `
    -Output @('[{"name":"bug","url":"https://github.com/other/repo/labels/bug"},{"name":"docs","url":"https://github.com/other/repo/labels/docs"}]')
try {
    $listed = @(Get-GitHubLabel -Repository 'other/repo')
}
finally {
    Remove-FakeGitHubCli -Fixture $listing
}

$fake = New-FakeGitHubCli
try {
    # Act
    $listed | Set-GitHubLabel -Color 'AABBCC'
    $listed[0] | Set-GitHubLabel -Color 'AABBCC' -Repository 'Other/Repo'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal `
        -Expected @('label', 'edit', '--color=AABBCC', '--repo', 'https://github.com/other/repo', '--', 'bug') `
        -Actual $calls[0].Arguments `
        -Message 'A piped label is changed in the repository its Url names, not the current one'
    Assert-Equal `
        -Expected @('label', 'edit', '--color=AABBCC', '--repo', 'https://github.com/other/repo', '--', 'docs') `
        -Actual $calls[1].Arguments `
        -Message 'each in its own call'
    Assert-Equal -Expected @('label', 'edit', '--color=AABBCC', '--repo', 'github.com/other/repo', '--', 'bug') `
        -Actual $calls[2].Arguments `
        -Message 'A repository named as a parameter that agrees with the label''s own keeps the label''s host'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nothing to change, a label from another repository than the one named, and a repository given as $null
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        $listed[0] | Set-GitHubLabel -Color '000000' -Repository 'o/r'
    } -MessageLike "'https://github.com/other/repo/labels/bug' is in other/repo, but -Repository names o/r: give one or the other." `
        -Message 'A piped label from another repository than -Repository names is refused, naming both'
    Assert-Throws -ScriptBlock {
        Set-GitHubLabel -Name 'bug'
    } -MessageLike 'Say what to change - -NewName, -Color, or -Description.' `
        -Message 'A call that changes nothing is refused before gh, which would refuse it too'
    Assert-Throws -ScriptBlock {
        Set-GitHubLabel -Name 'bug' -Description ''
    } -MessageLike '-Description is empty, and gh cannot clear a label''s description - it drops an empty one: give the new text, or leave -Description out.' `
        -Message 'An empty description is refused, since gh drops it rather than clearing the description'
    Assert-Throws -ScriptBlock {
        Set-GitHubLabel -Name 'bug' -Color '000000' -Description ''
    } -MessageLike '-Description is empty*' `
        -Message 'even beside another change, which gh would make while silently keeping the description'
    Assert-Throws -ScriptBlock {
        'https://github.com/a/b/labels/bug' | Set-GitHubLabel -Color '000000' -Repository 'c/d'
    } -MessageLike "'https://github.com/a/b/labels/bug' is in a/b, but -Repository names c/d: give one or the other." `
        -Message 'A label''s URL from another repository than -Repository names is refused'
    Assert-Throws -ScriptBlock {
        Set-GitHubLabel -Name 'bug' -Color '000000' -Repository $null
    } -MessageLike '-Repository was given, but it is $null*' `
        -Message 'A $null repository throws instead of changing the current directory''s label'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf beside every change, then -WhatIf:$false and -Confirm:$false
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @(Set-GitHubLabel -Name 'bug' -NewName 'defect' -Color 'FF0000' -Description 'd' -Repository 'o/r' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf gh is not called, so the label is not changed'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'

    # Act
    Set-GitHubLabel -Name 'bug' -NewName 'defect' -Color 'FF0000' -Description 'd' -Repository 'o/r' -WhatIf:$false `
        -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @('label', 'edit', '--name=defect', '--color=FF0000', '--description=d', '--repo', 'o/r', '--', 'bug') `
        -Actual $call.Arguments `
        -Message '-WhatIf:$false and -Confirm:$false change it as before, neither one reaching gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two labels piped in with -WhatIf
$fake = New-FakeGitHubCli
try {
    # Act
    $out = @('a', 'b' | Set-GitHubLabel -Color 'AABBCC' -Repository 'o/r' -WhatIf)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @() -Actual $calls -Message 'With -WhatIf neither piped label is changed'
    Assert-Equal -Expected @() -Actual $out -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with nothing to change, and with a label's URL from another repository
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubLabel -Name 'bug' -WhatIf
    } -MessageLike 'Say what to change - -NewName, -Color, or -Description.' `
        -Message '-WhatIf still refuses a call that changes nothing'
    Assert-Throws -ScriptBlock {
        Set-GitHubLabel -Name 'https://github.com/a/b/labels/bug' -Color '000000' -Repository 'c/d' -WhatIf
    } -MessageLike "'https://github.com/a/b/labels/bug' is in a/b, but -Repository names c/d: give one or the other." `
        -Message 'and a label from another repository'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the What-if lines for two labels piped in, with a credential in -Repository's URL
$fake = New-FakeGitHubCli
try {
    # Act
    $result = Get-WhatIfOutput -ScriptBlock {
        'a', 'b' | Set-GitHubLabel -Color 'AABBCC' -Repository 'https://user:SENTINEL@github.com/o/r' -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Edit label" on target "o/r label a".'
        'What if: Performing the operation "Edit label" on target "o/r label b".'
    )
    Assert-Equal -Expected $expected -Actual $result.Messages `
        -Message 'Each piped label gets its own line, in the repository named without the credential'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
