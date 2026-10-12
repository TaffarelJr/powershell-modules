#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') `
    -Force
. (Join-Path $PSScriptRoot 'GitHubWorkflowCommandsTestHelper.ps1')
$module = Get-Module TaffarelJr.GitHub.WorkflowCommands

$nodeOptionsMessage = 'NODE_OPTIONS cannot be set for later steps: the runner refuses it from GITHUB_ENV. ' +
    'Set it in the workflow''s own env instead.'
$badLine = '-Line is ''abc'', which is not a whole number: give one from 1 to 2147483647, or leave it out.'
$annotations = 'Write-GitHubActionsError', 'Write-GitHubActionsWarning', 'Write-GitHubActionsNotice'

$sandbox = New-WorkflowCommandsSandbox
$originalNodeOptions = $env:NODE_OPTIONS
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function with a process block, failing before it changes anything
    $path = New-CommandFile -Variable 'GITHUB_ENV' -Directory $sandbox

    # Act / Assert
    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        $caught = $null
        $output = @()
        try {
            $output = @(Set-GitHubActionsEnvironmentVariable -Name 'NODE_OPTIONS' -Value '--x' -ErrorAction $preference)
        }
        catch {
            $caught = $_
        }

        Assert-That -Condition ($null -ne $caught) -Message "-ErrorAction $preference does not swallow the failure"
        Assert-Equal -Expected 'RuntimeException,Set-GitHubActionsEnvironmentVariable' `
            -Actual $caught.FullyQualifiedErrorId `
            -Message 'which is a terminating error with the exception''s type as its ID'
        Assert-Equal -Expected 'InvalidOperation' -Actual ([string]$caught.CategoryInfo.Category) `
            -Message 'the InvalidOperation category'
        Assert-Equal -Expected $nodeOptionsMessage -Actual $caught.TargetObject `
            -Message 'and the target it was thrown with'
        Assert-Equal -Expected $nodeOptionsMessage -Actual $caught.Exception.Message -Message 'and its own message'
        Assert-Equal -Expected 0L -Actual ([IO.FileInfo]::new($path).Length) `
            -Message 'Nothing is written to the environment file'
        Assert-Equal -Expected $originalNodeOptions -Actual $env:NODE_OPTIONS `
            -Message 'and this process''s variable is not set'
        Assert-Equal -Expected 0 -Actual $output.Count -Message 'and nothing is returned'
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Set-GitHubActionsEnvironmentVariable -Name 'NODE_OPTIONS' -Value '--x' -ErrorAction Stop
    } -MessageLike ([WildcardPattern]::Escape($nodeOptionsMessage)) `
        -Message 'Under -ErrorAction Stop the call still throws'
}
finally {
    $env:NODE_OPTIONS = $originalNodeOptions
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a function with only an end body, whose script block throws
foreach ($preference in 'SilentlyContinue', 'Ignore') {
    Install-FakeLineWriter
    $caught = $null
    $output = @()
    $block = {
        throw 'boom'
        'after the throw'
    }

    # Act
    try {
        $output = @(Invoke-GitHubActionsLogGroup -Title 'g' -ScriptBlock $block -ErrorAction $preference)
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-That -Condition ($null -ne $caught) -Message "-ErrorAction $preference does not swallow a throw in the block"
    Assert-Equal -Expected 'RuntimeException,Invoke-GitHubActionsLogGroup' -Actual $caught.FullyQualifiedErrorId `
        -Message 'which is a terminating error with the exception''s type as its ID'
    Assert-Equal -Expected 'InvalidOperation' -Actual ([string]$caught.CategoryInfo.Category) `
        -Message 'the InvalidOperation category'
    Assert-Equal -Expected 'boom' -Actual $caught.TargetObject -Message 'and the target it was thrown with'
    Assert-Equal -Expected @('::group::g', '::endgroup::') -Actual @(Get-WrittenLine) `
        -Message 'and the group is still ended'
    Assert-Equal -Expected 0 -Actual $output.Count `
        -Message 'and the rest of the block does not run, so nothing is returned'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Install-FakeLineWriter

# Act / Assert
Assert-Throws -ScriptBlock { Invoke-GitHubActionsLogGroup -Title 'g' -ScriptBlock { throw 'boom' } -ErrorAction Stop } `
    -MessageLike 'boom' -Message 'Under -ErrorAction Stop the call still throws'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a script with no try/catch around its calls, as a workflow step has none, where a plain throw in a
# function is skipped under these preferences; the failing calls run in a new pwsh
$script = @'
Remove-Item Env:\NODE_OPTIONS -ErrorAction SilentlyContinue
$sandbox = Join-Path ([IO.Path]::GetTempPath()) "workflowcommands-handlerless-$PID"
New-Item -ItemType Directory -Path $sandbox | Out-Null
$env:GITHUB_ENV = Join-Path $sandbox 'env.txt'
[IO.File]::WriteAllBytes($env:GITHUB_ENV, [byte[]]@())
foreach ($preference in 'SilentlyContinue', 'Ignore') {
    $ErrorActionPreference = 'SilentlyContinue'
    $output = @(Set-GitHubActionsEnvironmentVariable -Name 'NODE_OPTIONS' -Value '--x' -ErrorAction $preference)
    $ErrorActionPreference = 'Stop'
    "env $preference file=$([IO.FileInfo]::new($env:GITHUB_ENV).Length) output=$($output.Count) variable=[$env:NODE_OPTIONS]"
}

foreach ($name in 'Write-GitHubActionsError', 'Write-GitHubActionsWarning', 'Write-GitHubActionsNotice') {
    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        $ErrorActionPreference = 'SilentlyContinue'
        & $name -Message 'x' -Line 'abc' -ErrorAction $preference
        $ErrorActionPreference = 'Stop'
        "$name $preference returned"
    }
}

Remove-Item -LiteralPath $sandbox -Recurse -Force
'@

# Act
$run = Invoke-ChildPowerShell -Script $script

# Assert
Assert-Equal -Expected @(
    'env SilentlyContinue file=0 output=0 variable=[]'
    'env Ignore file=0 output=0 variable=[]'
    'Write-GitHubActionsError SilentlyContinue returned'
    'Write-GitHubActionsError Ignore returned'
    'Write-GitHubActionsWarning SilentlyContinue returned'
    'Write-GitHubActionsWarning Ignore returned'
    'Write-GitHubActionsNotice SilentlyContinue returned'
    'Write-GitHubActionsNotice Ignore returned'
) -Actual $run.Lines `
    -Message 'A failing call does not carry on to its change under -ErrorAction SilentlyContinue or Ignore'
Assert-Equal -Expected 0 -Actual $run.ExitCode -Message 'and the script runs to its end'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the runner's standard output cannot be written to
& $module {
    function script:Write-GitHubActionsLine {
        throw [System.IO.IOException]::new('stdout is closed')
    }
}

$writers = @(
    @{ Name = 'Enter-GitHubActionsLogGroup'; Splat = @{ Title = 'g' } }
    @{ Name = 'Exit-GitHubActionsLogGroup'; Splat = @{} }
    @{ Name = 'Write-GitHubActionsDebug'; Splat = @{ Message = 'm' } }
    @{ Name = 'Hide-GitHubActionsValue'; Splat = @{ Value = 'secret' } }
    @{ Name = 'Write-GitHubActionsNotice'; Splat = @{ Message = 'm' } }
)

# Act / Assert
foreach ($writer in $writers) {
    $name = $writer.Name
    foreach ($preference in 'SilentlyContinue', 'Ignore', 'Stop') {
        $splat = $writer.Splat + @{ ErrorAction = $preference }
        $caught = $null
        try {
            & $name @splat
        }
        catch {
            $caught = $_
        }

        Assert-That -Condition ($null -ne $caught) -Message "$name raises when the line cannot be written, -ErrorAction $preference"
        Assert-Equal -Expected "IOException,$name" -Actual $caught.FullyQualifiedErrorId `
            -Message 'a terminating error with the exception''s type as its ID'
        Assert-Equal -Expected 'InvalidOperation' -Actual ([string]$caught.CategoryInfo.Category) `
            -Message 'and the InvalidOperation category'
        Assert-Equal -Expected 'stdout is closed' -Actual $caught.Exception.Message -Message 'and its own message'
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the annotation functions have a begin block, which checks the parameters
foreach ($name in $annotations) {
    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        Install-FakeLineWriter
        $caught = $null

        # Act
        try {
            & $name -Message 'x' -Line 'abc' -ErrorAction $preference
        }
        catch {
            $caught = $_
        }

        # Assert
        Assert-That -Condition ($null -ne $caught) -Message "$name raises for a bad -Line, -ErrorAction $preference"
        Assert-Equal -Expected "RuntimeException,$name" -Actual $caught.FullyQualifiedErrorId `
            -Message 'a terminating error with the exception''s type as its ID'
        Assert-Equal -Expected 'InvalidOperation' -Actual ([string]$caught.CategoryInfo.Category) `
            -Message 'the InvalidOperation category'
        Assert-Equal -Expected $badLine -Actual $caught.TargetObject -Message 'and the target it was thrown with'
        Assert-Equal -Expected @() -Actual @(Get-WrittenLine) -Message 'and no annotation is written'
    }

    # Act / Assert
    Assert-Throws -ScriptBlock { & $name -Message 'x' -Line 'abc' -ErrorAction Stop } `
        -MessageLike ([WildcardPattern]::Escape($badLine)) -Message 'Under -ErrorAction Stop the call still throws'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pipeline of three records for the annotation functions, the second not one they can write
$records = @(
    [PSCustomObject]@{ Message = 'first' }
    [PSCustomObject]@{ Other = 'no message' }
    [PSCustomObject]@{ Message = 'third' }
)
$firstLine = @{
    'Write-GitHubActionsError'   = '::error::first'
    'Write-GitHubActionsWarning' = '::warning::first'
    'Write-GitHubActionsNotice'  = '::notice::first'
}

# Act / Assert
foreach ($name in $annotations) {
    Install-FakeLineWriter
    $caught = $null
    try {
        $records | & $name
    }
    catch {
        $caught = $_
    }

    Assert-Equal -Expected @($firstLine[$name]) -Actual @(Get-WrittenLine) `
        -Message "$name writes the record before the bad one, and none after it"
    Assert-Equal -Expected "RuntimeException,$name" -Actual $caught.FullyQualifiedErrorId `
        -Message 'and raises a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pipeline of three values for Hide-GitHubActionsValue, the second not text
Install-FakeLineWriter
$caught = $null

# Act
try {
    'first', 5, 'third' | Hide-GitHubActionsValue
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected @('::add-mask::first') -Actual @(Get-WrittenLine) `
    -Message 'Hide-GitHubActionsValue masks the value before the bad one, and none after it'
Assert-Equal -Expected 'RuntimeException,Hide-GitHubActionsValue' -Actual $caught.FullyQualifiedErrorId `
    -Message 'and raises a terminating error'

$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a pipeline of three entries for each writer of a runner command file, the second with a bad name
    $entries = @(
        [PSCustomObject]@{ Name = 'WFC_PIPE_A'; Value = '1' }
        [PSCustomObject]@{ Name = 'WFC_PIPE=B'; Value = '2' }
        [PSCustomObject]@{ Name = 'WFC_PIPE_C'; Value = '3' }
    )
    $files = @(
        @{ Name = 'Set-GitHubActionsOutput'; Variable = 'GITHUB_OUTPUT' }
        @{ Name = 'Save-GitHubActionsState'; Variable = 'GITHUB_STATE' }
        @{ Name = 'Set-GitHubActionsEnvironmentVariable'; Variable = 'GITHUB_ENV' }
    )

    # Act / Assert
    foreach ($file in $files) {
        $name = $file.Name
        $path = New-CommandFile -Variable $file.Variable -Directory $sandbox
        $caught = $null
        try {
            $entries | & $name
        }
        catch {
            $caught = $_
        }

        Assert-Equal -Expected @('WFC_PIPE_A') -Actual @((Read-CommandFileEntry -Path $path).Name) `
            -Message "$name writes the record before the bad one, and none after it"
        Assert-Equal -Expected "ParameterArgumentValidationError,ConvertTo-GitHubActionsCommandFileText,$name" `
            -Actual $caught.FullyQualifiedErrorId -Message 'and raises a terminating error'
        Assert-Equal -Expected 'InvalidData' -Actual ([string]$caught.CategoryInfo.Category) `
            -Message 'whose category is the one the validation gave it'
    }

    Assert-Equal -Expected '1' -Actual $env:WFC_PIPE_A -Message 'The environment variable of the first record is set'
    Assert-Equal -Expected $null -Actual $env:WFC_PIPE_C -Message 'and that of the record after the bad one is not'
}
finally {
    Remove-Item Env:\WFC_PIPE_A -ErrorAction SilentlyContinue
    Remove-Item Env:\WFC_PIPE_C -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

$sandbox = New-WorkflowCommandsSandbox
$originalPath = $env:PATH
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a pipeline of three folders for Add-GitHubActionsPath, the second holding the path separator
    $separator = [System.IO.Path]::PathSeparator
    $path = New-CommandFile -Variable 'GITHUB_PATH' -Directory $sandbox
    $one = Join-Path $sandbox 'one'
    $two = Join-Path $sandbox "two${separator}x"
    $three = Join-Path $sandbox 'three'
    $caught = $null

    # Act
    try {
        $one, $two, $three | Add-GitHubActionsPath
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected "$one`n" -Actual ([IO.File]::ReadAllText($path)) `
        -Message 'Add-GitHubActionsPath adds the folder before the bad one, and none after it'
    Assert-Equal -Expected 'RuntimeException,Add-GitHubActionsPath' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and raises a terminating error'
}
finally {
    $env:PATH = $originalPath
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

$sandbox = New-WorkflowCommandsSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a pipeline of three lines for Add-GitHubActionsStepSummary, the second past the 1 MiB limit
    $path = New-CommandFile -Variable 'GITHUB_STEP_SUMMARY' -Directory $sandbox
    [IO.File]::WriteAllBytes($path, [byte[]]::new(1024 * 1024 - 10))
    $caught = $null

    # Act
    try {
        'a', ('b' * 12), 'c' | Add-GitHubActionsStepSummary
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected ([long](1024 * 1024 - 8)) -Actual ([IO.FileInfo]::new($path).Length) `
        -Message 'Add-GitHubActionsStepSummary appends the line before the bad one, and none after it'
    Assert-Equal -Expected 'RuntimeException,Add-GitHubActionsStepSummary' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and raises a terminating error'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
