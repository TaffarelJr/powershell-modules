#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')

$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $path = New-CommandFile -Variable 'GITHUB_STATE' -Directory $sandbox

    # Act
    Save-GitHubActionsState -Name 'containerId' -Value 'abc123'
    $entries = @(Read-CommandFileEntry -Path $path)

    # Assert
    Assert-Equal -Expected @([PSCustomObject]@{ Name = 'containerId'; Value = 'abc123' }) -Actual $entries `
        -Message 'The state is appended to the state file, for the runner to read back'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $path = New-CommandFile -Variable 'GITHUB_STATE' -Directory $sandbox -Name 'piped.txt'
    $states = @(
        [PSCustomObject]@{ Name = 'a'; Value = '1' }
        [PSCustomObject]@{ Name = 'b'; Value = '' }
    )

    # Act
    $states | Save-GitHubActionsState
    $entries = @(Read-CommandFileEntry -Path $path)

    # Assert
    Assert-Equal -Expected $states -Actual $entries `
        -Message 'Names and values are taken from piped objects, an empty value included'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Save-GitHubActionsState -Name ' ' -Value 'x' } `
        -MessageLike '*-Name is blank: give a name.' `
        -Message 'A blank name is refused, saying so'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - not running inside a step
    Remove-Item Env:\GITHUB_STATE -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Throws -ScriptBlock { Save-GitHubActionsState -Name 'x' -Value 'y' } `
        -MessageLike '*GITHUB_STATE is not set*' `
        -Message 'With GITHUB_STATE unset, Save-GitHubActionsState throws'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every parameter, and with states piped in
$sandbox = New-WorkflowCommandsSandbox
try {
    $path = New-CommandFile -Variable 'GITHUB_STATE' -Directory $sandbox
    $states = @(
        [PSCustomObject]@{ Name = 'a'; Value = 'VALUE_SENTINEL' }
        [PSCustomObject]@{ Name = 'b'; Value = "two`nVALUE_SENTINEL" }
    )

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Save-GitHubActionsState -Name 'version' -Value 'VALUE_SENTINEL' -WhatIf
        $states | Save-GitHubActionsState -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Save action state" on target "version".'
        'What if: Performing the operation "Save action state" on target "a".'
        'What if: Performing the operation "Save action state" on target "b".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each state'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') -Message 'and never its value'
    Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) `
        -Message 'and nothing is written to the state file'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names the runner could not read back as one name
$sandbox = New-WorkflowCommandsSandbox
try {
    $path = New-CommandFile -Variable 'GITHUB_STATE' -Directory $sandbox
    $cases = @(
        @{ Name = "evil`nINJECTED"; Message = 'A name with a line break is refused' }
        @{ Name = 'a=b'; Message = 'as is one holding =' }
        @{ Name = 'a<<b'; Message = 'or <<' }
        @{ Name = 'x<'; Message = 'or ending in <' }
    )

    # Act / Assert
    foreach ($case in $cases) {
        Assert-Throws -ScriptBlock { Save-GitHubActionsState -Name $case.Name -Value 'v' } `
            -MessageLike "*is not a name a command file can hold: no line break, '=', '<<', or final '<'." `
            -Message $case.Message
    }

    Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) -Message 'and nothing is written for any'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a NUL in the name or in the value
$sandbox = New-WorkflowCommandsSandbox
try {
    $path = New-CommandFile -Variable 'GITHUB_STATE' -Directory $sandbox

    # Act / Assert
    Assert-Throws -ScriptBlock { Save-GitHubActionsState -Name "a`0b" -Value 'v' } `
        -MessageLike '*is not a name a command file can hold: it has a control character other than a tab.' `
        -Message 'A name with a NUL is refused'
    Assert-Throws -ScriptBlock { Save-GitHubActionsState -Name 'a' -Value "x`0y" } `
        -MessageLike '*-Value holds a NUL character, which is not text: leave it out.' `
        -Message 'as is a value with one'
    Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) -Message 'and nothing is written for either'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the file GITHUB_STATE names is not there
$sandbox = New-WorkflowCommandsSandbox
try {
    $env:GITHUB_STATE = Join-Path $sandbox 'missing.txt'

    # Act / Assert
    Assert-Throws -ScriptBlock { Save-GitHubActionsState -Name 'n' -Value 'v' } `
        -MessageLike '*GITHUB_STATE points at*which is not a file*' -Message 'A missing state file throws'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $env:GITHUB_STATE) -Message 'and is not created'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$sandbox = New-WorkflowCommandsSandbox
try {
    $null = New-CommandFile -Variable 'GITHUB_STATE' -Directory $sandbox

    # Act / Assert
    Assert-Throws -ScriptBlock { Save-GitHubActionsState -Name 'a=b' -Value 'x' -WhatIf } `
        -MessageLike "*'a=b' is not a name a command file can hold: no line break, '=', '<<', or final '<'." `
        -Message 'With -WhatIf, a name the runner could not read back is still refused'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - not running inside a step
Remove-Item Env:\GITHUB_STATE -ErrorAction SilentlyContinue

# Act / Assert
Assert-Throws -ScriptBlock { Save-GitHubActionsState -Name 'x' -Value 'y' -WhatIf } `
    -MessageLike '*GITHUB_STATE is not set*' `
    -Message 'With -WhatIf, a call outside a step still throws'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$sandbox = New-WorkflowCommandsSandbox
try {
    $path = New-CommandFile -Variable 'GITHUB_STATE' -Directory $sandbox

    # Act
    Save-GitHubActionsState -Name 'version' -Value '1.2.3' -Confirm:$false
    $entries = @(Read-CommandFileEntry -Path $path)

    # Assert
    Assert-Equal -Expected @([PSCustomObject]@{ Name = 'version'; Value = '1.2.3' }) -Actual $entries `
        -Message '-Confirm:$false writes the state'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
