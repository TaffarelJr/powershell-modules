#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot '..' 'GitHubWorkflowCommandsTestHelper.ps1')

$originalToken = $env:GITHUB_TOKEN
$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $path = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox

    # Act
    Set-GitHubActionsEnvironmentVariable -Name 'WFC_TEST_CONFIG' -Value 'Release'
    $entries = @(Read-CommandFileEntry -Path $path)

    # Assert
    Assert-Equal -Expected @([PSCustomObject]@{ Name = 'WFC_TEST_CONFIG'; Value = 'Release' }) -Actual $entries `
        -Message 'The variable is appended to the env file, for the runner to read back'
    Assert-Equal -Expected 'Release' -Actual $env:WFC_TEST_CONFIG `
        -Message 'The variable also takes effect in this process immediately'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $path = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox -Name 'empty.txt'
    $env:WFC_TEST_EMPTY = 'set before'

    # Act
    Set-GitHubActionsEnvironmentVariable -Name 'WFC_TEST_EMPTY' -Value ''
    $entries = @(Read-CommandFileEntry -Path $path)

    # Assert
    Assert-Equal -Expected @([PSCustomObject]@{ Name = 'WFC_TEST_EMPTY'; Value = '' }) -Actual $entries `
        -Message 'An empty value is written for later steps as an empty value'
    Assert-That -Condition (-not (Test-Path -LiteralPath 'Env:\WFC_TEST_EMPTY')) `
        -Message 'and removes the variable from this process'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - GITHUB_ and RUNNER_ names the runner does not set itself
    $path = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox -Name 'passed-on.txt'

    # Act
    Set-GitHubActionsEnvironmentVariable -Name 'GITHUB_TOKEN' -Value 'wfc-test-token'
    Set-GitHubActionsEnvironmentVariable -Name 'RUNNER_WFC_TEST' -Value 'mine'
    $entries = @(Read-CommandFileEntry -Path $path)

    # Assert
    Assert-Equal -Expected @(
        [PSCustomObject]@{ Name = 'GITHUB_TOKEN'; Value = 'wfc-test-token' }
        [PSCustomObject]@{ Name = 'RUNNER_WFC_TEST'; Value = 'mine' }
    ) -Actual $entries -Message 'A GITHUB_ or RUNNER_ name the runner does not set is written, as later steps do see it'
    Assert-Equal -Expected 'wfc-test-token' -Actual $env:GITHUB_TOKEN -Message 'and takes effect in this process'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - names the runner refuses or sets for every step
    $path = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox -Name 'refused.txt'
    $before = $env:GITHUB_OUTPUT
    $cases = @(
        @{
            Name = 'NODE_OPTIONS'
            Like = '*NODE_OPTIONS cannot be set for later steps*'
            Message = 'NODE_OPTIONS is refused, as the runner refuses it from GITHUB_ENV'
        }
        @{ Name = 'node_options'; Like = '*NODE_OPTIONS cannot be set for later steps*'; Message = 'in any casing' }
        @{
            Name = 'GITHUB_OUTPUT'
            Like = "'GITHUB_OUTPUT' is set by the runner for every step*Give another name."
            Message = 'A GITHUB_ name the runner sets is refused, as later steps would see the runner''s value'
        }
        @{ Name = 'GITHUB_ACTIONS'; Like = "'GITHUB_ACTIONS' is set by the runner*"; Message = 'as is GITHUB_ACTIONS' }
        @{
            Name = 'RUNNER_TEMP'
            Like = "'RUNNER_TEMP' is set by the runner*"
            Message = 'as is a RUNNER_ name the runner sets'
        }
    )

    # Act / Assert
    foreach ($case in $cases) {
        Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name $case.Name -Value 'x' } `
            -MessageLike $case.Like `
            -Message $case.Message
    }

    Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) `
        -Message 'and nothing is written for any of them'
    Assert-Equal -Expected $before -Actual $env:GITHUB_OUTPUT -Message 'and nothing is changed in this process'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a runner name in lower case, where environment names ignore case (Windows) and where they keep it
    $path = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox -Name 'casing.txt'
    $beforeCasing = [Environment]::GetEnvironmentVariable('runner_environment')
    $originalIsWindows = $IsWindows
    try {
        Set-Variable -Name IsWindows -Value $true -Force -Scope Global

        # Act / Assert
        Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name 'runner_environment' -Value 'x' } `
            -MessageLike "'runner_environment' is set by the runner for every step*Give another name." `
            -Message 'On Windows, a runner name in another casing is refused, as the name is the same one there'
        Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) -Message 'and nothing is written'

        # Arrange
        Set-Variable -Name IsWindows -Value $false -Force -Scope Global

        # Act
        Set-GitHubActionsEnvironmentVariable -Name 'runner_environment' -Value 'x'
        $entries = @(Read-CommandFileEntry -Path $path)

        # Assert
        Assert-Equal -Expected @([PSCustomObject]@{ Name = 'runner_environment'; Value = 'x' }) -Actual $entries `
            -Message 'Elsewhere, where names keep their case, the same name in lower case is another variable'
    }
    finally {
        Set-Variable -Name IsWindows -Value $originalIsWindows -Force -Scope Global
        [Environment]::SetEnvironmentVariable('runner_environment', $beforeCasing)
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a NUL in the name or in the value
    $path = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox -Name 'nul.txt'
    [Environment]::SetEnvironmentVariable('WFC_TEST_NUL', $null)

    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name "WFC_TEST_NUL`0X" -Value 'v' } `
        -MessageLike '*is not a name a command file can hold: it has a control character other than a tab.' `
        -Message 'A name with a NUL is refused'
    Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name 'WFC_TEST_NUL' -Value "a`0b" } `
        -MessageLike '*-Value holds a NUL character, which is not text: leave it out.' `
        -Message 'as is a value with one, which this process would have kept only up to the NUL'
    Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) -Message 'and nothing is written for either'
    Assert-Equal -Expected $null -Actual $env:WFC_TEST_NUL -Message 'and nothing is set in this process'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name ' ' -Value 'x' } `
        -MessageLike '*-Name is blank: give a name.' `
        -Message 'A blank name is refused, saying so'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - not running inside a step
    Remove-Item Env:\GITHUB_ENV -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name 'X' -Value 'y' } `
        -MessageLike '*GITHUB_ENV is not set*' `
        -Message 'With GITHUB_ENV unset, Set-GitHubActionsEnvironmentVariable throws'
}
finally {
    Remove-Item Env:\WFC_TEST_CONFIG, Env:\WFC_TEST_EMPTY, Env:\RUNNER_WFC_TEST -ErrorAction SilentlyContinue
    $env:GITHUB_TOKEN = $originalToken
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every parameter, and with variables piped in
$sandbox = New-WorkflowCommandsSandbox
try {
    $path = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox
    $variables = @(
        [PSCustomObject]@{ Name = 'WHATIF_PROBE_A'; Value = 'VALUE_SENTINEL' }
        [PSCustomObject]@{ Name = 'WHATIF_PROBE_B'; Value = "two`nVALUE_SENTINEL" }
    )

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Set-GitHubActionsEnvironmentVariable -Name 'WHATIF_PROBE' -Value 'VALUE_SENTINEL' -WhatIf
        $variables | Set-GitHubActionsEnvironmentVariable -WhatIf
    }
    $names = @('WHATIF_PROBE', 'WHATIF_PROBE_A', 'WHATIF_PROBE_B')
    $set = @($names.Where({ $null -ne [Environment]::GetEnvironmentVariable($_) }))

    # Assert
    $operation = 'What if: Performing the operation "Set environment variable for later steps and this process"'
    $expected = @(
        "$operation on target ""WHATIF_PROBE""."
        "$operation on target ""WHATIF_PROBE_A""."
        "$operation on target ""WHATIF_PROBE_B""."
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each variable'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') -Message 'and never its value'
    Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) `
        -Message 'and nothing is written to the environment file'
    Assert-Equal -Expected 0 -Actual $set.Count -Message 'nor set in this process'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names the runner could not read back as one name
$sandbox = New-WorkflowCommandsSandbox
try {
    $path = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox
    $cases = @(
        @{ Name = "WFC_EVIL`nINJECTED"; Message = 'A name with a line break is refused' }
        @{ Name = 'WFC_A=B'; Message = 'as is one holding =' }
        @{ Name = 'WFC_A<<B'; Message = 'or <<' }
        @{ Name = 'WFC_X<'; Message = 'or ending in <' }
    )

    # Act / Assert
    foreach ($case in $cases) {
        Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name $case.Name -Value 'v' } `
            -MessageLike "*is not a name a command file can hold: no line break, '=', '<<', or final '<'." `
            -Message $case.Message
    }

    $set = @($cases.Where({ $null -ne [Environment]::GetEnvironmentVariable($_.Name) }))
    Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) -Message 'and nothing is written for any'
    Assert-Equal -Expected 0 -Actual $set.Count -Message 'nor set in this process'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the file GITHUB_ENV names is not there
$sandbox = New-WorkflowCommandsSandbox
try {
    $env:GITHUB_ENV = Join-Path $sandbox 'missing.txt'

    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name 'WFC_MISSING' -Value 'v' } `
        -MessageLike '*GITHUB_ENV points at*which is not a file*' -Message 'A missing environment file throws'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $env:GITHUB_ENV) -Message 'and is not created'
    Assert-Equal -Expected $null -Actual $env:WFC_MISSING -Message 'and the variable is not set'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$sandbox = New-WorkflowCommandsSandbox
try {
    $null = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox

    # Act / Assert
    Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name 'NODE_OPTIONS' -Value 'x' -WhatIf } `
        -MessageLike 'NODE_OPTIONS cannot be set for later steps: the runner refuses it from GITHUB_ENV.*' `
        -Message 'With -WhatIf, a name the runner refuses is still refused'
    Assert-Throws -ScriptBlock { Set-GitHubActionsEnvironmentVariable -Name 'a=b' -Value 'x' -WhatIf } `
        -MessageLike "*'a=b' is not a name a command file can hold: no line break, '=', '<<', or final '<'." `
        -Message 'as is one the runner could not read back'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$sandbox = New-WorkflowCommandsSandbox
try {
    $path = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox

    # Act
    Set-GitHubActionsEnvironmentVariable -Name 'WHATIF_PROBE' -Value 'set' -Confirm:$false
    $entries = @(Read-CommandFileEntry -Path $path)

    # Assert
    Assert-Equal -Expected @([PSCustomObject]@{ Name = 'WHATIF_PROBE'; Value = 'set' }) -Actual $entries `
        -Message '-Confirm:$false writes the variable'
    Assert-Equal -Expected 'set' -Actual $env:WHATIF_PROBE -Message 'and sets it in this process'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\WHATIF_PROBE -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
