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

$originalPath = $env:PATH
$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $pathFile = New-CommandFile -Variable 'GITHUB_PATH' -Directory $sandbox
    $toolDir = Join-Path $sandbox 'tools'

    # Act
    Add-GitHubActionsPath -Path $toolDir
    $text = [File]::ReadAllText($pathFile)

    # Assert
    Assert-Equal -Expected "$toolDir`n" -Actual $text `
        -Message 'The directory is appended to the path file as a plain, unescaped line'
    Assert-That -Condition ($env:PATH.StartsWith($toolDir + [Path]::PathSeparator)) `
        -Message 'The directory is also prepended to this process''s own PATH immediately'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a second directory, added after the first
    $secondDir = Join-Path $sandbox 'more-tools'

    # Act
    Add-GitHubActionsPath -Path $secondDir
    $text = [File]::ReadAllText($pathFile)

    # Assert
    Assert-Equal -Expected "$toolDir`n$secondDir`n" -Actual $text `
        -Message 'A second call appends another line rather than overwriting the first'
    Assert-That -Condition ($env:PATH.StartsWith($secondDir + [Path]::PathSeparator)) `
        -Message 'The most recently added directory comes first on PATH'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative directory and a relative path file, with
    # PowerShell and the process in different folders
    $here = Join-Path $sandbox 'here'
    $there = Join-Path $sandbox 'there'
    New-Item -ItemType Directory -Path $here, $there | Out-Null
    $herePathFile = New-CommandFile -Variable 'GITHUB_PATH' -Directory $here -Name 'path.txt'
    $null = New-CommandFile -Variable 'GITHUB_PATH' -Directory $there -Name 'path.txt'
    $env:GITHUB_PATH = 'path.txt'

    # Act
    Use-SplitLocation -Location $here -ProcessDirectory $there -ScriptBlock {
        Add-GitHubActionsPath -Path './bin'
    }

    $text = [File]::ReadAllText($herePathFile)

    # Assert
    Assert-Equal -Expected "$(Join-Path $here 'bin')`n" -Actual $text `
        -Message 'Both are taken from PowerShell''s location, and the directory is written as a full path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $pathFile = New-CommandFile -Variable 'GITHUB_PATH' -Directory $sandbox -Name 'refused.txt'
    $separator = [Path]::PathSeparator
    $cases = @(
        @{
            Path    = "/opt/tools`n/opt/evil"
            Like    = '*is not a path the path file can hold: it must not be blank or contain a line break.'
            Message = 'A path holding a line break is refused, as it would add a second entry of its own'
        }
        @{
            Path    = '   '
            Like    = '*is not a path the path file can hold: it must not be blank or contain a line break.'
            Message = 'A blank path is refused, saying so'
        }
        @{
            Path    = (Join-Path $sandbox 'a') + $separator + (Join-Path $sandbox 'b')
            Like    = "*holds the path separator '$separator'*"
            Message = 'A path holding the path separator is refused, as PATH would read it as two folders'
        }
    )

    # Act / Assert
    foreach ($case in $cases) {
        Assert-Throws -ScriptBlock { Add-GitHubActionsPath -Path $case.Path } -MessageLike $case.Like `
            -Message $case.Message
    }

    Assert-Equal -Expected 0L -Actual ([FileInfo]::new($pathFile).Length) `
        -Message 'and nothing is written for any of them'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a relative path given while PowerShell is in the
    # environment provider
    Assert-Throws -ScriptBlock {
        Push-Location -LiteralPath 'Env:\'
        try {
            Add-GitHubActionsPath -Path 'tools'
        }
        finally {
            Pop-Location
        }
    } -MessageLike "-Path is 'tools', which resolves to a path on the Environment provider, not a folder; *" `
        -Message 'A path that resolves outside the file system is refused'
    Assert-Equal -Expected 0L -Actual ([FileInfo]::new($pathFile).Length) -Message 'and nothing is written for it'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a path on a drive that does not exist
    Assert-Throws -ScriptBlock { Add-GitHubActionsPath -Path 'NoSuchDrive:\tools' } `
        -MessageLike "-Path is 'NoSuchDrive:\tools', which PowerShell cannot resolve: *NoSuchDrive*" `
        -Message 'A path PowerShell cannot resolve throws naming -Path and the value'
    Assert-Equal -Expected 0L -Actual ([FileInfo]::new($pathFile).Length) `
        -Message 'and nothing is written for it, either'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - not running inside a step
    Remove-Item Env:\GITHUB_PATH -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitHubActionsPath -Path $toolDir } -MessageLike '*GITHUB_PATH is not set*' `
        -Message 'With GITHUB_PATH unset, Add-GitHubActionsPath throws'
}
finally {
    $env:PATH = $originalPath
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf, and with directories piped in
$sandbox = New-WorkflowCommandsSandbox
try {
    $pathFile = New-CommandFile -Variable 'GITHUB_PATH' -Directory $sandbox
    $before = $env:PATH

    $folders = @((Join-Path $sandbox 'a'), (Join-Path $sandbox 'b'))

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Add-GitHubActionsPath -Path (Join-Path $sandbox 'tools') -WhatIf
        $folders | Add-GitHubActionsPath -WhatIf
    }

    # Assert
    $expected = @(
        "What if: Performing the operation ""Add to PATH"" on target ""$(Join-Path $sandbox 'tools')""."
        "What if: Performing the operation ""Add to PATH"" on target ""$($folders[0])""."
        "What if: Performing the operation ""Add to PATH"" on target ""$($folders[1])""."
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each full directory'
    Assert-Equal -Expected 0L -Actual ([FileInfo]::new($pathFile).Length) `
        -Message 'and nothing is written to the path file'
    Assert-Equal -Expected $before -Actual $env:PATH -Message 'nor to this process''s PATH'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    $env:PATH = $originalPath
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the file GITHUB_PATH names is not there
$sandbox = New-WorkflowCommandsSandbox
try {
    $env:GITHUB_PATH = Join-Path $sandbox 'missing.txt'
    $before = $env:PATH

    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitHubActionsPath -Path (Join-Path $sandbox 'tools') } `
        -MessageLike '*GITHUB_PATH points at*which is not a file*' -Message 'A missing path file throws'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $env:GITHUB_PATH) -Message 'and is not created'
    Assert-Equal -Expected $before -Actual $env:PATH -Message 'and this process''s PATH is left alone'
}
finally {
    $env:PATH = $originalPath
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$sandbox = New-WorkflowCommandsSandbox
try {
    $null = New-CommandFile -Variable 'GITHUB_PATH' -Directory $sandbox
    $twoFolders = (Join-Path $sandbox 'a') + [Path]::PathSeparator + (Join-Path $sandbox 'b')

    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitHubActionsPath -Path $twoFolders -WhatIf } `
        -MessageLike "*holds the path separator*add each folder with a call of its own." `
        -Message 'With -WhatIf, a path PATH would read as two folders is still refused'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$sandbox = New-WorkflowCommandsSandbox
try {
    $pathFile = New-CommandFile -Variable 'GITHUB_PATH' -Directory $sandbox
    $toolDir = Join-Path $sandbox 'tools'

    # Act
    Add-GitHubActionsPath -Path $toolDir -Confirm:$false

    # Assert
    Assert-Equal -Expected "$toolDir`n" -Actual ([File]::ReadAllText($pathFile)) `
        -Message '-Confirm:$false writes the directory'
    Assert-That -Condition ($env:PATH.StartsWith($toolDir + [Path]::PathSeparator)) `
        -Message 'and puts it first on this process''s PATH'
}
finally {
    $env:PATH = $originalPath
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
