#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot 'GitHubGistsTestHelper.ps1')

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case.
$elsewhere = [System.IO.Path]::GetTempPath()
$gistId = 'bcd1234567890abcdef0'
$assertMessage = {
    param([scriptblock]$Block, [string]$Expected, [string]$Name)
    Assert-Throws -ScriptBlock $Block -MessageLike ([WildcardPattern]::Escape($Expected)) -Message $Name
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every message that shows a value it was given, with no gh run: a
# gist, then local files named from a folder whose name looks like a credential
$notGist = ' is not a gist: give its id or URL, or a gist object.'
$notUtf8 = ' is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first.'
$noContent = ' is empty or only whitespace, and GitHub refuses a gist file with no content.'
$files = @{
    'SENTINEL@h.example/empty.txt'   = ''
    'SENTINEL@h.example/bin.dat'     = [byte[]](0x41, 0x00, 0x42)
    'SENTINEL@h.example/latin1.txt'  = [byte[]](0x63, 0x61, 0x66, 0xE9)
    'SENTINEL@h.example/u16bom.txt'  = [byte[]](0xFF, 0xFE, 0x68, 0x00)
    'SENTINEL@h.example/u16le.txt'   = [byte[]](0x68, 0x00, 0x69, 0x00)
    'SENTINEL@h.example/ok.txt'      = 'text'
}
$folder = New-GistTestFolder -File $files
$messages = @(
    @{
        Block = { Remove-GitHubGist -Id 'https://user:SENTINEL@h.example/me/nope' }
        Expected = "'https://***@h.example/me/nope'$notGist"
        Name = 'ConvertTo-GitHubGistId, for a URL'
    }
    @{
        Block = { Get-GitHubGist -Id 'SENTINEL@h.example/me/nope' }
        Expected = "'***@h.example/me/nope'$notGist"
        Name = 'for text with no scheme'
    }
    @{
        Block = {
            [PSCustomObject]@{ Url = 'https://user:SENTINEL@h.example/me/nope' } | Set-GitHubGist -Description 'x'
        }
        Expected = "'https://***@h.example/me/nope'$notGist"
        Name = 'and for the Url of a gist object'
    }
    @{
        Block = { New-GitHubGist -Path 'SENTINEL@h.example/missing.txt' }
        Expected = "'***@h.example/missing.txt' is not a file."
        Name = 'Resolve-GitHubGistSource, for a file that is not there'
    }
    @{
        Block = { New-GitHubGist -Path 'SENTINEL@h.example/none*' }
        Expected = "'***@h.example/none*' matches no file."
        Name = 'and for a wildcard that matches no file'
    }
    @{
        Block = { New-GitHubGist -Path 'SENTINEL@h.example/empty.txt.' }
        Expected = "'***@h.example/empty.txt.' is not a file."
        Name = 'Get-GitHubGistLocalFile, for a name no entry of the folder has'
    }
    @{
        Block = { New-GitHubGist -Path 'Env:/user:SENTINEL@h.example/x' }
        Expected = "'***@h.example/x' is not a file system path (it is on the Environment provider)," +
        ' so gh cannot use it.'
        Name = 'Resolve-GitHubGistSource, for a path off the file system'
    }
    @{
        Block = { New-GitHubGist -Path 'Env:/user:SENTINEL@h.example/x*' }
        Expected = "'***@h.example/x*' is not a file system path (it is on the Environment provider)," +
        ' so gh cannot use it.'
        Name = 'and for a wildcard off the file system'
    }
    @{
        Block = { New-GitHubGist -Path 'SENTINEL@h.example/empty.txt' }
        Expected = "'***@h.example/empty.txt'$noContent"
        Name = 'Assert-GitHubGistText, for an empty file'
    }
    @{
        Block = { New-GitHubGist -Path 'SENTINEL@h.example/bin.dat' }
        Expected = "'***@h.example/bin.dat' holds binary data, and a gist holds text only."
        Name = 'Read-GitHubGistFile, for a binary file'
    }
    @{
        Block = { New-GitHubGist -Path 'SENTINEL@h.example/latin1.txt' }
        Expected = "'***@h.example/latin1.txt'$notUtf8"
        Name = 'for a file in another encoding'
    }
    @{
        Block = { New-GitHubGist -Path 'SENTINEL@h.example/u16bom.txt' }
        Expected = "'***@h.example/u16bom.txt'$notUtf8"
        Name = 'for UTF-16 with a byte-order mark'
    }
    @{
        Block = { New-GitHubGist -Path 'SENTINEL@h.example/u16le.txt' }
        Expected = "'***@h.example/u16le.txt'$notUtf8"
        Name = 'and for UTF-16 without one'
    }
    @{
        Block = { Set-GitHubGist -Id $gistId -AddFile 'SENTINEL@h.example/none.txt' }
        Expected = "-AddFile '***@h.example/none.txt' is not a file."
        Name = 'Set-GitHubGist, for an -AddFile that is not there'
    }
    @{
        Block = { Set-GitHubGist -Id $gistId -AddFile 'SENTINEL@h.example/empty.txt.' }
        Expected = "-AddFile '***@h.example/empty.txt.' is not a file."
        Name = 'for an -AddFile no entry of the folder has'
    }
    @{
        Block = { Set-GitHubGist -Id $gistId -AddFile 'SENTINEL@h.example/empty.txt' }
        Expected = "-AddFile '***@h.example/empty.txt'$noContent"
        Name = 'for an -AddFile with no content'
    }
    @{
        Block = { Set-GitHubGist -Id $gistId -FileName 'a.txt' -ReplaceWith 'SENTINEL@h.example/none.txt' }
        Expected = "-ReplaceWith '***@h.example/none.txt' is not a file."
        Name = 'for a -ReplaceWith that is not there'
    }
    @{
        Block = { Set-GitHubGist -Id $gistId -FileName 'a.txt' -ReplaceWith 'SENTINEL@h.example/bin.dat' }
        Expected = "-ReplaceWith '***@h.example/bin.dat' holds binary data, and a gist holds text only."
        Name = 'and for a -ReplaceWith that is binary'
    }
)
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        foreach ($case in $messages) {
            & $assertMessage $case.Block $case.Expected "$($case.Name) shows no credential"
        }
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'all before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file a wildcard matches, in a folder whose name holds the credential
# A folder name holds ':' only off Windows, and the colon is what lets a path
# be read as USER:PASSWORD@; on Windows the drive's own colon does.
$credentialFolder = if ($IsWindows) { 'SENTINEL@h.example' } else { 'user:SENTINEL@h.example' }
$root = New-GistTestFolder -File @{ "$credentialFolder/empty.txt" = '' }
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Use-SplitLocation -Location (Join-Path $root $credentialFolder) -ProcessDirectory $elsewhere -ScriptBlock {
        Assert-Throws -ScriptBlock {
            New-GitHubGist -Path 'emp*.txt'
        } -MessageLike "'*[*]@h.example?empty.txt'$([WildcardPattern]::Escape($noContent))" `
            -Message 'A file a wildcard matched is named by its full path, without the credential'
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $root -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf, with names that look like a credential
$folder = New-GistTestFolder -File $files
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Get-WhatIfOutput -ScriptBlock {
            New-GitHubGist -Content 'x' -FileName 'user:SENTINEL@h.example' -WhatIf
            Rename-GitHubGistFile -Id $gistId -OldName 'user:SENTINEL@h.example' -NewName 'u2:SENTINEL@h.example' `
                -WhatIf
            Set-GitHubGist -Id $gistId -RemoveFile 'user:SENTINEL@h.example' -WhatIf
            Set-GitHubGist -Id $gistId -FileName 'user:SENTINEL@h.example' -ReplaceWith 'SENTINEL@h.example/ok.txt' `
                -WhatIf
        }
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Create secret gist" on target "***@h.example".'
        "What if: Performing the operation ""Rename file ***@h.example to ***@h.example"" on target ""gist $gistId""."
        "What if: Performing the operation ""Remove file ***@h.example"" on target ""gist $gistId""."
        "What if: Performing the operation ""Replace file ***@h.example"" on target ""gist $gistId""."
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf shows no credential in a name'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and nothing is sent'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that fails, echoing a URL with a credential on its error stream
$failure = 'fatal: https://user:SENTINEL@h.example/x forbidden'
$shownFailure = 'fatal: https://***@h.example/x forbidden'
$failures = @(
    @{
        Block = { Get-GitHubGist -Id $gistId }
        Expected = "Reading gist $gistId failed: gh api gists/$gistId (exit 1)`n$shownFailure"
        Name = 'Invoke-GitHubGistApi, for what gh printed'
    }
    @{
        Block = { Set-GitHubGist -Id $gistId -Description 'see https://user:SENTINEL@h.example/x' }
        Expected = "Setting the description of gist $gistId failed: gh api gists/$gistId --method PATCH" +
        " --raw-field 'description=see https://***@h.example/x' --silent (exit 1)`n$shownFailure"
        Name = 'and for a description in the call'
    }
    @{
        Block = { Set-GitHubGist -Id $gistId -RemoveFile 'user:SENTINEL@h.example' }
        Expected = "Editing gist $gistId failed: gh gist edit ***@h.example $gistId (exit 1)`n$shownFailure"
        Name = 'Set-GitHubGist, for a file name in the call'
    }
    @{
        Block = {
            Rename-GitHubGistFile -Id $gistId -OldName 'user:SENTINEL@h.example' -NewName 'u2:SENTINEL@h.example'
        }
        Expected = "Renaming ***@h.example in gist $gistId failed: gh gist rename -- $gistId ***@h.example" +
        " ***@h.example (exit 1)`n$shownFailure"
        Name = 'Rename-GitHubGistFile, for both names'
    }
    @{
        Block = { New-GitHubGist -Content 'x' -FileName 'user:SENTINEL@h.example' }
        Expected = "Creating the gist failed: gh api gists --method POST --input - (exit 1)`n$shownFailure"
        Name = 'New-GitHubGist, for what gh printed'
    }
    @{
        Block = { Remove-GitHubGist -Id $gistId }
        Expected = "Deleting gist $gistId failed: gh gist delete $gistId --yes (exit 1)`n$shownFailure"
        Name = 'Remove-GitHubGist, for what gh printed'
    }
)
$fake = New-FakeGitHubCli -ErrorOutput @($failure) -ExitCode 1
try {
    # Act / Assert
    foreach ($case in $failures) {
        & $assertMessage $case.Block $case.Expected "$($case.Name) shows no credential"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gist whose id, as GitHub's answer gives it, looks like a credential
$fake = New-FakeGitHubCli -Output @('{"id":"user:SENTINEL@h.example","truncated":true,"files":{}}')
try {
    # Act
    $warnings = @(Get-WarningOutput -ScriptBlock {
            Get-GitHubGist -Id $gistId | Out-Null
        })

    # Assert
    $expected = 'Gist ***@h.example has more than 300 files, and GitHub lists only the first 300 in Files:' +
    ' clone it with Copy-GitHubGist for every file.'
    Assert-Equal -Expected @($expected) -Actual $warnings `
        -Message 'The warning about a truncated gist shows no credential'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

# The cases below replace functions of the module for the rest of the file's
# process, so each comes after every case that needs the original.

#───────────────────────────────────────────────────────────────────────────────
# Arrange - local files whose names hold a ':', which no Windows file name can
Use-ReplacedFunction -Module $module -Name 'Resolve-GitHubGistSource' -Body {
    param([string]$Path)
    [PSCustomObject]@{ Path = $Path; Source = "'$Path'" }
}
Use-ReplacedFunction -Module $module -Name 'Read-GitHubGistFile' -Body {
    'text'
}
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    & $assertMessage {
        New-GitHubGist -Path '/w/user:SENTINEL@h.example/a.txt', '/w/user:SENTINEL@h.example/a.txt'
    } "-Path names the file '/w/***@h.example/a.txt' more than once: give each file once." `
        'New-GitHubGist shows no credential in a path it was given twice'
    & $assertMessage {
        New-GitHubGist -Path '/one/user:SENTINEL@h.example', '/two/user:SENTINEL@h.example'
    } "More than one of the -Path files is named '***@h.example', and a gist holds one file per name." `
        'and none in a file name two files have'

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        New-GitHubGist -Path '/w/plain.txt', '/w/user:SENTINEL@h.example' -WhatIf
    }

    # Assert
    $expected = 'What if: Performing the operation "Create secret gist" on target "plain.txt, ***@h.example".'
    Assert-Equal -Expected @($expected) -Actual $whatIf.Messages `
        -Message 'and none in the names -WhatIf lists, each hidden on its own'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'all before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file to add, whose name in the file system holds a ':'
$folder = New-GistTestFolder -File @{ 'SENTINEL@h.example/ok.txt' = 'text' }
Use-ReplacedFunction -Module $module -Name 'Get-GitHubGistLocalFile' -Body {
    '/w/user:SENTINEL@h.example'
}
try {
    $alreadyThere = '{"id":"' + $gistId + '","files":{"user:SENTINEL@h.example":{"filename":"x"}}}'
    $cutShort = '{"id":"' + $gistId + '","truncated":true,"files":{}}'
    $other = '{"id":"' + $gistId + '","files":{"other.txt":{"filename":"other.txt"}}}'
    $replaced = "Gist $gistId already has a file named '***@h.example', which -AddFile would silently replace;" +
    " to replace it, give -FileName '***@h.example' -ReplaceWith '***@h.example/ok.txt'."
    $notChecked = "Gist $gistId has more than 300 files, and GitHub lists only the first 300, so whether it already" +
    " has a file named '***@h.example' cannot be told: clone it with Copy-GitHubGist and add the file there."

    # Act / Assert
    $fake = New-FakeGitHubCli -Output @($alreadyThere)
    try {
        Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            & $assertMessage {
                Set-GitHubGist -Id $gistId -AddFile 'SENTINEL@h.example/ok.txt'
            } $replaced 'Set-GitHubGist shows no credential in the name of a file the gist has'
        }
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    $fake = New-FakeGitHubCli -Output @($cutShort)
    try {
        Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            & $assertMessage {
                Set-GitHubGist -Id $gistId -AddFile 'SENTINEL@h.example/ok.txt'
            } $notChecked 'and none in the name of the file it cannot check'
        }
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }

    # Act
    $fake = New-FakeGitHubCli -Output @($other)
    try {
        $whatIf = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            Get-WhatIfOutput -ScriptBlock {
                Set-GitHubGist -Id $gistId -AddFile 'SENTINEL@h.example/ok.txt' -WhatIf
            }
        }

        # Assert
        $expected = "What if: Performing the operation ""Add file ***@h.example"" on target ""gist $gistId""."
        Assert-Equal -Expected @($expected) -Actual $whatIf.Messages `
            -Message 'and none in the name -WhatIf says it would add'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a destination folder whose full path holds a credential, and a
# location that is no folder
Use-ReplacedFunction -Module $module -Name 'Resolve-GitHubPath' -Body {
    '/w/user:SENTINEL@h.example/dest'
}
$fake = New-FakeGitHubCli -ErrorOutput @($failure) -ExitCode 1
try {
    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Copy-GitHubGist -Id $gistId -Destination 'dest' -WhatIf
    }

    # Assert
    $expected = "What if: Performing the operation ""Clone gist $gistId"" on target ""/w/***@h.example/dest""."
    Assert-Equal -Expected @($expected) -Actual $whatIf.Messages `
        -Message 'Copy-GitHubGist -WhatIf shows no credential in the folder'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and clones nothing'

    # Act / Assert
    & $assertMessage {
        Copy-GitHubGist -Id $gistId -Destination 'dest'
    } "Cloning gist $gistId failed: gh gist clone $gistId /w/***@h.example/dest (exit 1)`n$shownFailure" `
        'and a failed clone shows none in the folder it passed to gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no destination, while PowerShell's location is a registry key whose
# name holds a credential
Use-ReplacedFunction -Module $module -Name 'Get-Location' -Body {
    $place = [PSCustomObject]@{ Provider = [PSCustomObject]@{ Name = 'Registry' } }
    $place | Add-Member -MemberType ScriptMethod -Name ToString -Force -Value {
        'HKCU:\Software\user:SENTINEL@h.example'
    }
    return $place
}
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    $expected = "PowerShell's location, ***@h.example, is not a folder, so no gist can be cloned under it:" +
    ' give -Destination, or go to a folder first.'
    & $assertMessage {
        Copy-GitHubGist -Id $gistId
    } $expected 'Copy-GitHubGist shows no credential in a location that is not a folder'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
