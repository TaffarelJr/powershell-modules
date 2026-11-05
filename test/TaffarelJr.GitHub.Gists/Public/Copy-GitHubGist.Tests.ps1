#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Gists/TaffarelJr.GitHub.Gists.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'GitHubGistsTestHelper.ps1')

# The fake gh clones nothing, so each folder a clone would create is made
# beforehand, for the folder the function returns to exist.
$elsewhere = [System.IO.Path]::GetTempPath()

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a destination folder, relative to PowerShell's location
$folder = New-GistTestFolder -Folder @('notes')
$fake = New-FakeGitHubCli
try {
    # Act
    $clone = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Copy-GitHubGist -Id 'bcd1234567890abcdef0' -Destination './notes'
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('gist', 'clone', 'bcd1234567890abcdef0', (Join-Path $folder 'notes')) `
        -Actual $call.Arguments `
        -Message 'The id and the destination are both positional, the destination resolved from PowerShell''s location'
    Assert-Equal -Expected (Join-Path $folder 'notes') -Actual $clone.FullName -Message 'The cloned folder is returned'
    Assert-That -Condition ($clone -is [System.IO.DirectoryInfo]) -Message 'as a folder object'
    Assert-Equal -Expected $false -Actual $call.StdInPiped -Message 'and nothing is piped to gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gist ids from the pipeline, with no destination
$folder = New-GistTestFolder -Folder @('a', 'b')
$fake = New-FakeGitHubCli
try {
    # Act
    $clones = @(Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
            @('a', 'b') | Copy-GitHubGist
        })
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped gist is cloned in its own call'
    Assert-Equal -Expected @('gist', 'clone', 'b', (Join-Path $folder 'b')) -Actual $calls[1].Arguments `
        -Message 'Without -Destination, each goes into a folder named for its id, under PowerShell''s location'
    Assert-Equal -Expected @((Join-Path $folder 'a'), (Join-Path $folder 'b')) -Actual @($clones.FullName) `
        -Message 'and each cloned folder is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the gist given as a URL, and as a listed object
$folder = New-GistTestFolder -Folder @('bcd1234567890abcdef0', 'fedcba9876543210fedc')
$fake = New-FakeGitHubCli
try {
    # Act
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Copy-GitHubGist -Id 'https://gist.github.com/me/bcd1234567890abcdef0' | Out-Null
        [PSCustomObject]@{
            Id = 'fedcba9876543210fedc'
            HtmlUrl = 'https://gist.github.com/me/fedcba9876543210fedc'
        } | Copy-GitHubGist | Out-Null
    }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 'bcd1234567890abcdef0' -Actual $calls[0].Arguments[2] `
        -Message 'A gist URL is reduced to its bare id'
    Assert-Equal -Expected 'fedcba9876543210fedc' -Actual $calls[1].Arguments[2] `
        -Message 'and a piped gist object is read by its Id'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a destination that starts with dashes, which gh would hand to git
$folder = New-GistTestFolder -Folder @('--upload-pack=x')
$fake = New-FakeGitHubCli
try {
    # Act
    Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Copy-GitHubGist -Id 'bcd1234567890abcdef0' -Destination '--upload-pack=x' | Out-Null
    }
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected (Join-Path $folder '--upload-pack=x') -Actual $call.Arguments[3] `
        -Message 'reaches gh as a full path, never as an option'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that are not a gist, or not a folder on disk
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Copy-GitHubGist -Id '--help'
    } -MessageLike "*'--help' is not a gist: give its id or URL, or a gist object." `
        -Message 'A gist that is not an id is refused'
    Assert-Throws -ScriptBlock {
        Copy-GitHubGist -Id 'bcd1234567890abcdef0' -Destination 'Env:\x'
    } -MessageLike "*'Env:\x' is not a file system path*" -Message 'A destination off the file system is refused'
    Assert-Throws -ScriptBlock {
        Copy-GitHubGist -Id 'bcd1234567890abcdef0' -Destination ' '
    } -MessageLike '*-Destination is blank: give a folder, or leave it out.' -Message 'and so is a blank one'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no destination, while PowerShell's location is off the file system
$fake = New-FakeGitHubCli
Push-Location -LiteralPath 'Env:\'
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Copy-GitHubGist -Id 'bcd1234567890abcdef0'
    } -MessageLike "PowerShell's location, Env:\, is not a folder, so no gist can be cloned under it: give -Destination, or go to a folder first." `
        -Message 'A location that is not a folder is refused, not blamed on the gist id'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Pop-Location
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a full destination, while PowerShell's location is off the file
# system
$folder = New-GistTestFolder -Folder @('notes')
$fake = New-FakeGitHubCli
Push-Location -LiteralPath 'Env:\'
try {
    # Act
    $clone = Copy-GitHubGist -Id 'bcd1234567890abcdef0' -Destination (Join-Path $folder 'notes')

    # Assert
    Assert-Equal -Expected (Join-Path $folder 'notes') -Actual $clone.FullName `
        -Message 'A full -Destination clones from there all the same'
}
finally {
    Pop-Location
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh cannot clone the gist
$folder = New-GistTestFolder
$fake = New-FakeGitHubCli `
    -ErrorOutput @('fatal: destination path ''notes'' already exists and is not an empty directory.') `
    -ExitCode 128
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Copy-GitHubGist -Id 'bcd1234567890abcdef0' -Destination (Join-Path $folder 'notes')
    } -MessageLike '*Cloning gist bcd1234567890abcdef0 failed*already exists and is not an empty directory*' `
        -Message 'A failed clone throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a destination that does not exist yet
$folder = New-GistTestFolder
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Get-WhatIfOutput -ScriptBlock {
            Copy-GitHubGist -Id 'bcd1234567890abcdef0' -Destination './notes' -WhatIf
        }
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Clone gist bcd1234567890abcdef0"' +
        " on target `"$(Join-Path $folder 'notes')`"."
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names the folder, resolved from PowerShell''s location, and the gist'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'returns no folder'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'calls no gh'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $folder 'notes')) `
        -Message 'and makes no folder'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with a blank destination, and one off the file system
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Copy-GitHubGist -Id 'bcd1234567890abcdef0' -Destination ' ' -WhatIf
    } -MessageLike '*-Destination is blank: give a folder, or leave it out.' `
        -Message '-WhatIf still refuses a blank destination'
    Assert-Throws -ScriptBlock {
        Copy-GitHubGist -Id 'bcd1234567890abcdef0' -Destination 'Env:\x' -WhatIf
    } -MessageLike "*'Env:\x' is not a file system path*" -Message 'and one off the file system'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and calls no gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two gists piped under -WhatIf, with no destination
$folder = New-GistTestFolder
$fake = New-FakeGitHubCli
try {
    # Act
    $whatIf = Use-SplitLocation -Location $folder -ProcessDirectory $elsewhere -ScriptBlock {
        Get-WhatIfOutput -ScriptBlock {
            @('a1', 'b2') | Copy-GitHubGist -WhatIf
        }
    }

    # Assert
    $expected = @(
        "What if: Performing the operation `"Clone gist a1`" on target `"$(Join-Path $folder 'a1')`"."
        "What if: Performing the operation `"Clone gist b2`" on target `"$(Join-Path $folder 'b2')`"."
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each folder a gist would go into'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and clones neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
