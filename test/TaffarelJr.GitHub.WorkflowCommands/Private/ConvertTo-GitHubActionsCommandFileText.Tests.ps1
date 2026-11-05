#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')
$module = Get-Module TaffarelJr.GitHub.WorkflowCommands

$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $text = & $module { ConvertTo-GitHubActionsCommandFileText -Name 'greeting' -Value 'hello' }

    # Assert
    Assert-That `
        -Condition ($text -cmatch '^greeting<<ghadelimiter_[0-9a-f-]{36}\nhello\nghadelimiter_[0-9a-f-]{36}\n\z') `
        -Message 'The entry is the name<<delimiter / value / delimiter heredoc form, with LF line ends'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a value containing its own newlines, which a plain
    # NAME=VALUE line could never carry safely
    $path = Join-Path $sandbox 'multiline.txt'

    # Act
    $text = & $module { ConvertTo-GitHubActionsCommandFileText -Name 'notes' -Value "line one`r`nline two" }
    [File]::WriteAllText($path, $text)
    $entries = @(Read-CommandFileEntry -Path $path)

    # Assert
    Assert-Equal -Expected @([PSCustomObject]@{ Name = 'notes'; Value = "line one`r`nline two" }) -Actual $entries `
        -Message 'A multi-line value is read back intact'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - values with nothing in them, a final newline, and text
    # outside ASCII
    $path = Join-Path $sandbox 'round-trip.txt'

    # Act
    $texts = & $module {
        ConvertTo-GitHubActionsCommandFileText -Name 'empty' -Value ''
        ConvertTo-GitHubActionsCommandFileText -Name 'trailing' -Value "abc`n"
        ConvertTo-GitHubActionsCommandFileText -Name 'unicode' -Value 'héllo ✓'
    }
    [File]::WriteAllText($path, -join $texts)
    $entries = @(Read-CommandFileEntry -Path $path)

    # Assert
    $expected = @(
        [PSCustomObject]@{ Name = 'empty'; Value = '' }
        [PSCustomObject]@{ Name = 'trailing'; Value = "abc`n" }
        [PSCustomObject]@{ Name = 'unicode'; Value = 'héllo ✓' }
    )
    Assert-Equal -Expected $expected -Actual $entries `
        -Message 'An empty value, a final newline, and non-ASCII text are each read back exactly, in order'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two calls get two different delimiters, so a value that
    # happens to equal one call's delimiter can never collide with the other's

    # Act
    $texts = & $module {
        ConvertTo-GitHubActionsCommandFileText -Name 'a' -Value 'x'
        ConvertTo-GitHubActionsCommandFileText -Name 'b' -Value 'y'
    }
    $found = [Regex]::Matches((-join $texts), 'ghadelimiter_[0-9a-f-]+')
    $delimiters = @($found.Value | Select-Object -Unique)

    # Assert
    Assert-Equal -Expected 2 -Actual $delimiters.Count `
        -Message 'Each of the two calls uses its own, different delimiter'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - names the runner could not read back as one name
    $names = @(
        @{
            Name = "evil`nINJECTED"
            Message = 'A name with a line break is refused, as the rest would be read as an entry of its own'
        }
        @{ Name = "evil`r"; Message = 'as is one with a carriage return' }
        @{ Name = 'a=b'; Message = 'A name holding = is refused, as the runner would read the line as NAME=VALUE' }
        @{
            Name = 'a<<b'
            Message = 'A name holding << is refused, as the runner would take the rest for the delimiter'
        }
        @{
            Name = 'x<'
            Message = 'A name ending in < is refused, as with the << after it the runner would split a character early'
        }
        @{ Name = '<'; Message = 'as is a lone <, which would leave the runner an empty name' }
        @{ Name = '   '; Message = 'A name of nothing but spaces is refused' }
    )

    # Act / Assert
    foreach ($case in $names) {
        Assert-Throws -ScriptBlock {
            & $module { param($n) ConvertTo-GitHubActionsCommandFileText -Name $n -Value 'v' } $case.Name
        } -MessageLike "*is not a name a command file can hold: no line break, '=', '<<', or final '<'." `
            -Message $case.Message
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - names with a control character other than a tab
    $controls = @(
        @{ Name = "a`0b"; Message = 'A name with a NUL is refused' }
        @{ Name = "a$([char]0x01)b"; Message = 'as is one with another C0 control character' }
        @{ Name = "a$([char]0x0B)b"; Message = 'a vertical tab' }
        @{ Name = "a$([char]0x1F)b"; Message = 'the last of them' }
        @{ Name = "a$([char]0x7F)b"; Message = 'a delete' }
        @{ Name = "a$([char]0x85)b"; Message = 'and a C1 control character' }
    )

    # Act / Assert
    foreach ($case in $controls) {
        Assert-Throws -ScriptBlock {
            & $module { param($n) ConvertTo-GitHubActionsCommandFileText -Name $n -Value 'v' } $case.Name
        } -MessageLike '*is not a name a command file can hold: it has a control character other than a tab.' `
            -Message $case.Message
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a value with a NUL, and values with other control characters
    $nul = "a`0b"

    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { param($v) ConvertTo-GitHubActionsCommandFileText -Name 'n' -Value $v } $nul
    } -MessageLike '*-Value holds a NUL character, which is not text: leave it out.' `
        -Message 'A value with a NUL is refused, as an environment variable would be cut short at it'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $path = Join-Path $sandbox 'fine-names.txt'

    # Act
    $texts = & $module {
        ConvertTo-GitHubActionsCommandFileText -Name 'my output.v1' -Value 'v'
        ConvertTo-GitHubActionsCommandFileText -Name '<x' -Value 'w'
        ConvertTo-GitHubActionsCommandFileText -Name "tab`there" -Value "esc$([char]0x1B)[0m$([char]0x01)"
    }
    [File]::WriteAllText($path, -join $texts)
    $entries = @(Read-CommandFileEntry -Path $path)

    # Assert
    $expected = @(
        [PSCustomObject]@{ Name = 'my output.v1'; Value = 'v' }
        [PSCustomObject]@{ Name = '<x'; Value = 'w' }
        [PSCustomObject]@{ Name = "tab`there"; Value = "esc$([char]0x1B)[0m$([char]0x01)" }
    )
    Assert-Equal -Expected $expected -Actual $entries `
        -Message 'A name with a space, a dot, a tab, or a < that does not end it is written as it is'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
