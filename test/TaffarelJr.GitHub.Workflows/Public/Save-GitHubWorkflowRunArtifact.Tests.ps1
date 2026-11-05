#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one named artifact of one run, into a folder relative to the
# current location
$fake = New-FakeGitHubCli
$folder = Join-Path ([System.IO.Path]::GetTempPath()) "gh-artifacts-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
Push-Location -LiteralPath $folder
try {
    # Act
    Save-GitHubWorkflowRunArtifact -RunId 123 -Name @('packages') -Destination 'out' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('run', 'download', '123', '--name=packages', '--dir', (Join-Path $folder 'out'), '--repo', 'o/r')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'The run is positional, each option becomes its gh flag, and a relative -Destination is made full'
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $folder -Recurse -Force
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - destinations written the PowerShell way, which gh cannot read
$fake = New-FakeGitHubCli
try {
    # Act
    Save-GitHubWorkflowRunArtifact -RunId 1 -Destination '~/out'
    Save-GitHubWorkflowRunArtifact -RunId 1 -Destination 'Temp:/out'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected (Join-Path $HOME 'out') -Actual $calls[0].Arguments[4] -Message '~ is the home folder'
    Assert-Equal -Expected (Join-Path (Get-PSDrive -Name Temp).Root 'out') -Actual $calls[1].Arguments[4] `
        -Message 'and a PowerShell drive is the folder it stands for'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a destination on no file system
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Save-GitHubWorkflowRunArtifact -RunId 1 -Destination 'Env:/out'
    } -MessageLike "*'Env:/out' is not a file system path*" -Message 'A destination gh has no folder for is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - artifacts by name and pattern across every run
$fake = New-FakeGitHubCli
try {
    # Act
    Save-GitHubWorkflowRunArtifact -Name @('a', 'b') -Pattern @('*-report')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'download', '--name=a', '--name=b', '--pattern=*-report') `
        -Actual $call.Arguments `
        -Message 'Without -RunId, one --name per name and one --pattern per pattern'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every artifact, asked for on purpose
$fake = New-FakeGitHubCli
try {
    # Act
    Save-GitHubWorkflowRunArtifact -Pattern '*'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'download', '--pattern=*') -Actual $call.Arguments `
        -Message '-Pattern * asks for every artifact'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no run, no name, and no pattern, which gh reads as every artifact
# in the repository
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Save-GitHubWorkflowRunArtifact -Destination 'out'
    } -MessageLike "Give -RunId, -Name, or -Pattern*every artifact in the repository*-Pattern '*'*" `
        -Message 'A call naming nothing is refused, saying how to ask for everything'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - destinations given blank, which would extract into the current folder
$fake = New-FakeGitHubCli
try {
    foreach ($blank in '', '   ') {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            Save-GitHubWorkflowRunArtifact -RunId 1 -Destination $blank
        } -MessageLike '-Destination is blank: give a folder, or leave it out.' `
            -Message "A blank -Destination ('$blank') is refused"
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a destination ending in white space, which Windows cannot handle in a folder name and
# other platforms can. $IsWindows is forced, so both are tested here; it is read-only, hence -Force,
# and it is put back however the cases end.
$originalIsWindows = $IsWindows
$fake = New-FakeGitHubCli
try {
    Set-Variable -Name IsWindows -Value $true -Force -Scope Global

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Save-GitHubWorkflowRunArtifact -RunId 1 -Destination 'out '
    } -MessageLike ("-Destination 'out ' ends in white space, which Windows cannot handle in a folder name:" +
        ' give it without.') `
        -Message 'On Windows, a -Destination ending in white space is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'

    # Arrange
    Set-Variable -Name IsWindows -Value $false -Force -Scope Global

    # Act
    Save-GitHubWorkflowRunArtifact -RunId 1 -Destination 'out '
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'Elsewhere, where a folder name may end in a space, gh runs'
    Assert-Equal -Expected @('run', 'download', '1', '--dir') -Actual @($calls[0].Arguments[0..3]) `
        -Message 'into the folder named'
}
finally {
    Set-Variable -Name IsWindows -Value $originalIsWindows -Force -Scope Global
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - lists holding a blank name or pattern
$blanks = @(
    @{ Splat = @{ Name = @('', '') }; Parameter = 'Name'; Message = 'A list of blank names is refused' }
    @{ Splat = @{ Name = @('a', ' ') }; Parameter = 'Name'; Message = 'as is one blank name among others' }
    @{ Splat = @{ Name = '' }; Parameter = 'Name'; Message = 'and a lone empty name' }
    @{ Splat = @{ RunId = 1; Pattern = @('*', '') }; Parameter = 'Pattern'; Message = 'and a blank pattern' }
)
$fake = New-FakeGitHubCli
try {
    foreach ($case in $blanks) {
        $splat = $case.Splat
        $parameter = $case.Parameter

        # Act / Assert
        Assert-Throws -ScriptBlock {
            Save-GitHubWorkflowRunArtifact @splat
        } -MessageLike ("-$parameter has a blank element, which gh would read as no $($parameter.ToLowerInvariant())." +
            " Give each one, or leave -$parameter out.") `
            -Message $case.Message
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every other parameter, and with runs piped in
$fake = New-FakeGitHubCli
$folder = Join-Path ([System.IO.Path]::GetTempPath()) "gh-artifacts-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $folder | Out-Null
try {
    $destination = Join-Path $folder 'out'
    $options = @{
        Name        = @('packages')
        Pattern     = @('*-report')
        Destination = $destination
    }

    $runs = @(
        [PSCustomObject]@{ DatabaseId = 1; Repository = 'https://user:SENTINEL@github.com/a/b' }
        [PSCustomObject]@{ DatabaseId = 2 }
    )
    $here = (Get-Location -PSProvider FileSystem).ProviderPath

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Save-GitHubWorkflowRunArtifact -RunId 123 @options -Repository 'o/r' -WhatIf
        Save-GitHubWorkflowRunArtifact -Pattern '*' -Destination $destination -Repository 'o/r' -WhatIf
        Save-GitHubWorkflowRunArtifact -Pattern '*' -Repository 'https://user:SENTINEL@github.com/o/r' -WhatIf
        Save-GitHubWorkflowRunArtifact -Pattern '*' -WhatIf
        $runs | Save-GitHubWorkflowRunArtifact -Destination $destination -WhatIf
    }

    # Assert
    $operation = 'What if: Performing the operation'
    $expected = @(
        "$operation ""Download the matching artifacts of o/r workflow run 123"" on target ""$destination""."
        "$operation ""Download the latest matching artifacts of o/r"" on target ""$destination""."
        "$operation ""Download the latest matching artifacts of o/r"" on target ""$here""."
        ("$operation ""Download the latest matching artifacts of the current directory's repository""" +
            " on target ""$here"".")
        "$operation ""Download the artifacts of a/b workflow run 1"" on target ""$destination""."
        "$operation ""Download the artifacts of workflow run 2"" on target ""$destination""."
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names the folder, and the run or repository the artifacts come from'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') -Message 'and never shows a token'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $destination) -Message 'and no folder is made'
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Save-GitHubWorkflowRunArtifact -Destination 'out' -WhatIf
    } -MessageLike "Give -RunId, -Name, or -Pattern*every artifact in the repository*-Pattern '*'*" `
        -Message 'With -WhatIf, a call naming nothing is still refused'
    Assert-Throws -ScriptBlock {
        Save-GitHubWorkflowRunArtifact -RunId 1 -Destination 'Env:/out' -WhatIf
    } -MessageLike "*'Env:/out' is not a file system path*" `
        -Message 'as is a destination gh has no folder for'

    # Act
    Save-GitHubWorkflowRunArtifact -RunId 123 -Name 'packages' -Repository 'o/r' -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'download', '123', '--name=packages', '--repo', 'o/r') -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
