#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

# A plain throw is skipped, and the function carries on, only when nothing up the call stack catches it - so
# the failing call is made by a script in a runspace of its own, with no try and no trap around it.
$bare = {
    param([string]$Text)

    $shell.Commands.Clear()
    $shell.Streams.ClearStreams()
    $null = $shell.AddScript($Text)
    $output = @()
    $thrown = $null
    try {
        $output = @($shell.Invoke())
    }
    catch {
        $thrown = $_
    }

    $errors = @($shell.Streams.Error)
    $record = $null
    if ($errors.Count -gt 0) {
        $record = $errors[0]
    }
    elseif ($null -ne $thrown) {
        $record = $thrown.Exception.InnerException.ErrorRecord
    }

    [PSCustomObject]@{
        Output     = $output
        Stopped    = $null -ne $thrown
        ErrorCount = $errors.Count
        Error      = $record
    }
}
$attempt = {
    param([scriptblock]$Block)

    $output = @()
    $caught = $null
    try {
        $output = @(& $Block)
    }
    catch {
        $caught = $_
    }

    [PSCustomObject]@{
        Output = $output
        Error  = $caught
    }
}
$sent = {
    param($Calls)

    @($Calls | ForEach-Object { $_.Arguments -join ' ' })
}

$folder = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "boundary-$([Guid]::NewGuid())")
$shell = [PowerShell]::Create()
try {
    $key = Join-Path $folder 'deploy.pub'
    [IO.File]::WriteAllText($key, "ssh-ed25519 AAAA test`n", [Text.UTF8Encoding]::new($false))
    $null = $shell.AddScript({
            param($Root)

            Import-Module (Join-Path $Root 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1')
            Import-Module (Join-Path $Root 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1')
            Import-Module (Join-Path $Root 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1')
        }).AddArgument($repoRoot)
    $null = $shell.Invoke()

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a guard of this module in each kind of block, a different one for each: an end body (no named
    # block), a process block alone, a begin block, and the process block of a function that also has a begin
    $kinds = @(
        @{
            Kind   = 'an end body'
            Call   = "Add-GitHubDeployKey -KeyFile '$key' -Title ' ' -Repository 'o/r'"
            Id     = 'RuntimeException,Add-GitHubDeployKey'
            Target = '-Title is blank: give a title for the key, or leave it out.'
        }
        @{
            Kind   = 'a process block'
            Call   = "Remove-GitHubLabel -Name 'https://github.com/o/a' -Repository 'o/r'"
            Id     = 'RuntimeException,Remove-GitHubLabel'
            Target = "'https://github.com/o/a' is not a label: a URL must end in /OWNER/REPO/labels/NAME."
        }
        @{
            Kind   = 'a begin block'
            Call   = "Set-GitHubLabel -Name 'bug'"
            Id     = 'RuntimeException,Set-GitHubLabel'
            Target = 'Say what to change - -NewName, -Color, or -Description.'
        }
        @{
            Kind   = 'the process block of a function with a begin block'
            Call   = 'Set-GitHubRepository -Archived'
            Id     = 'RuntimeException,Set-GitHubRepository'
            Target = '-Visibility and -Archived change a repository for good, so name the repository with' +
            ' -Repository or pipe it in - the current directory''s is not assumed.'
        }
    )

    # Act / Assert - whatever the caller says about errors, the failing call stops before it changes anything,
    # and the next line of the caller's script still runs
    foreach ($kind in $kinds) {
        foreach ($preference in 'SilentlyContinue', 'Ignore', 'Continue', 'Stop') {
            $fake = New-FakeGitHubCli
            try {
                $result = & $bare "$($kind.Call) -ErrorAction $preference; 'after'"
                $calls = @(Get-FakeGitHubCall -Fixture $fake)
                $label = "A guard in $($kind.Kind), under -ErrorAction $preference"

                Assert-Equal -Expected @() -Actual $calls -Message "$label, stops before gh is called"
                Assert-Equal -Expected @('after') -Actual $result.Output `
                    -Message "$label, returns nothing, and the script goes on to its next line"
                Assert-Equal -Expected 1 -Actual $result.ErrorCount `
                    -Message "$label, raises one error, a terminating error for that call"
                Assert-Equal -Expected $kind.Id -Actual $result.Error.FullyQualifiedErrorId `
                    -Message "$label, gives it the function's own error ID"
                Assert-Equal -Expected 'InvalidOperation' -Actual $result.Error.CategoryInfo.Category.ToString() `
                    -Message "$label, puts it in a category a caller can act on"
                Assert-Equal -Expected $kind.Target -Actual $result.Error.TargetObject `
                    -Message "$label, keeps the target the failure recorded"
                Assert-Equal -Expected $kind.Target -Actual $result.Error.Exception.Message `
                    -Message "$label, keeps its message"
            }
            finally {
                Remove-FakeGitHubCli -Fixture $fake
            }
        }

        # Arrange - a script that stops on any error, as GitHub Actions' pwsh shell does
        $fake = New-FakeGitHubCli
        try {
            # Act
            $result = & $bare "& { `$ErrorActionPreference = 'Stop'; $($kind.Call); 'after' }"
            $calls = @(Get-FakeGitHubCall -Fixture $fake)

            # Assert
            $label = "A guard in $($kind.Kind), in a script that stops on errors"
            Assert-Equal -Expected @() -Actual $calls -Message "$label, stops before gh is called"
            Assert-That -Condition $result.Stopped -Message "$label, ends the script"
            Assert-Equal -Expected @() -Actual $result.Output -Message "$label, never reaches the next line"
            Assert-Equal -Expected $kind.Id -Actual $result.Error.FullyQualifiedErrorId `
                -Message "$label, ends it with the function's own error ID"
        }
        finally {
            Remove-FakeGitHubCli -Fixture $fake
        }
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a guard that lives in TaffarelJr.GitHub.Core, under each preference
    foreach ($preference in 'SilentlyContinue', 'Ignore', 'Stop') {
        $fake = New-FakeGitHubCli
        try {
            # Act
            $result = & $bare "Copy-GitHubLabel -Source 'o/r' -Repository `$null -ErrorAction $preference; 'after'"
            $calls = @(Get-FakeGitHubCall -Fixture $fake)

            # Assert
            $label = "A guard of the Core module, under -ErrorAction $preference"
            Assert-Equal -Expected @() -Actual $calls -Message "$label, stops before gh is called"
            Assert-Equal -Expected @('after') -Actual $result.Output `
                -Message "$label, returns nothing, and the script goes on to its next line"
            Assert-That -Condition ($result.Error.FullyQualifiedErrorId -like '*,Copy-GitHubLabel') `
                -Message "$label, ends the error ID with the calling function"
            Assert-Equal -Expected 'InvalidOperation' -Actual $result.Error.CategoryInfo.Category.ToString() `
                -Message "$label, puts it in a category a caller can act on"
        }
        finally {
            Remove-FakeGitHubCli -Fixture $fake
        }
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the first record is fine, the second is refused, and the third must never be reached
    $pipelines = @(
        @{
            Family   = 'labels'
            Block    = { 'a', 'https://github.com/o/a', 'c' | Remove-GitHubLabel -Repository 'o/r' }
            Expected = @('label delete --yes --repo o/r -- a')
            Id       = 'RuntimeException,Remove-GitHubLabel'
        }
        @{
            Family   = 'repositories'
            Block    = { 'o/a', 'two words', 'o/c' | Remove-GitHubRepository }
            Expected = @('repo delete o/a --yes')
            Id       = '*,Remove-GitHubRepository'
        }
        @{
            Family   = 'secrets'
            Block    = {
                [PSCustomObject]@{ Name = 'A'; Repository = 'o/r' },
                [PSCustomObject]@{ Name = 'B'; Repository = 'o/r'; Environment = 'prod'; Application = 'dependabot' },
                [PSCustomObject]@{ Name = 'C'; Repository = 'o/r' } | Remove-GitHubSecret
            }
            Expected = @('secret delete --repo o/r -- A')
            Id       = 'RuntimeException,Remove-GitHubSecret'
        }
        @{
            Family   = 'deploy keys'
            Block    = {
                [PSCustomObject]@{ Id = 1; Repository = 'o/r' },
                [PSCustomObject]@{ Id = 2; Repository = $null },
                [PSCustomObject]@{ Id = 3; Repository = 'o/r' } | Remove-GitHubDeployKey -Repository 'o/r'
            }
            Expected = @('repo deploy-key delete 1 --repo o/r')
            Id       = 'RuntimeException,Remove-GitHubDeployKey'
        }
        @{
            Family   = 'rulesets'
            Block    = {
                [PSCustomObject]@{ Id = 1; Source = 'o/r'; SourceType = 'Repository' },
                [PSCustomObject]@{ Id = 2; Source = 'o/r' },
                [PSCustomObject]@{ Id = 3; Source = 'o/r'; SourceType = 'Repository' } | Get-GitHubRuleset
            }
            Expected = @('api repos/o/r/rulesets/1')
            Id       = 'RuntimeException,Get-GitHubRuleset'
        }
    )

    # Act / Assert
    foreach ($pipeline in $pipelines) {
        $fake = New-FakeGitHubCli -Output @('{"id":1}')
        try {
            $result = & $attempt $pipeline.Block
            $calls = @(& $sent @(Get-FakeGitHubCall -Fixture $fake))

            Assert-Equal -Expected $pipeline.Expected -Actual $calls `
                -Message ("In the $($pipeline.Family) pipeline the records before the failure are handled" +
                    ' and none after it is')
            Assert-That -Condition ($result.Error.FullyQualifiedErrorId -like $pipeline.Id) `
                -Message "and the $($pipeline.Family) failure is a terminating error with an ID like $($pipeline.Id)"
        }
        finally {
            Remove-FakeGitHubCli -Fixture $fake
        }
    }
}
finally {
    $shell.Dispose()
    Remove-Item -LiteralPath $folder -Recurse -Force
}

exit (Complete-TestRun)
