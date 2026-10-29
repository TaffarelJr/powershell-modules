#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidOverwritingBuiltInCmdlets',
    '',
    Justification = 'One case stands in for the path lookup, inside one script block only.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') `
    -Force -PassThru
. (Join-Path $PSScriptRoot 'ProcessInvocationTestHelper.ps1')

# Every message is matched whole, its stars escaped, so a SENTINEL left anywhere
# in it fails the case.
$url = 'https://u:SENTINEL@h.example/o/r'
$shown = 'https://***@h.example/o/r'
$missing = 'https://u:SENTINEL@h.example/no-such-command'
$missingShown = 'https://***@h.example/no-such-command'
$escape = { param([string]$Text) [WildcardPattern]::Escape($Text) }
$leakProbe = {
    'fatal: could not read from https://u:SENTINEL@h.example/o/r'
    'first: fine'
    'see me@example.com'
    $global:LASTEXITCODE = 7
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Assert-ExitCode -Activity "Cloning $url" -ExitCode 1 } `
    -MessageLike (& $escape "Cloning $shown failed with exit code 1") `
    -Message 'Assert-ExitCode hides a credential in the activity'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a command that fails, given credentials in its arguments, and
# printing one; an @ in a later word or line must not hide an earlier one
Set-Item -Path function:global:Invoke-LeakProbe -Value $leakProbe
$arguments = @('clone', $url, "--repo=$url", 'user:SENTINEL@h.example/o/r', 'a:b', 'me@example.com')
$expected = "Cloning $shown failed: Invoke-LeakProbe clone '$shown' '--repo=$shown' '***@h.example/o/r' a:b" +
" me@example.com (exit 7)`nfatal: could not read from $shown`nfirst: fine`nsee me@example.com"

# Act / Assert
try {
    Assert-Throws `
        -ScriptBlock {
            Invoke-NativeCommand -Activity "Cloning $url" -Command 'Invoke-LeakProbe' -Argument $arguments
        } `
        -MessageLike (& $escape $expected) `
        -Message ('Invoke-NativeCommand hides a credential in the activity, in each word of the command line,' +
            ' and in each line printed, each on its own')
}
finally {
    Remove-Item -Path function:global:Invoke-LeakProbe
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a program of its own that writes a credential to stderr
$script = "[Console]::Error.WriteLine('remote: $url'); exit 3"
$shownScript = "'[Console]::Error.WriteLine(''remote: $shown''); exit 3'"
$pattern = (& $escape 'Pushing failed: ') + '*' +
(& $escape " -NoProfile -Command $shownScript (exit 3)`nremote: $shown")

# Act / Assert
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Pushing' -Command $pwsh -Argument @(
        '-NoProfile', '-Command', $script
    ) -SeparateStderr -TimeoutSeconds 60 } `
    -MessageLike $pattern `
    -Message 'and in what a program wrote to stderr, kept apart, on a process of its own'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a command that cannot be found, on each route
Assert-Throws -ScriptBlock { Invoke-NativeCommand -Activity "Cloning $url" -Command $missing } `
    -MessageLike ((& $escape "Cloning $shown failed: could not run $missingShown (The term '$missingShown'") + '*') `
    -Message 'A command that cannot be found is named hidden, in the message and in PowerShell''s reason'
Assert-Throws -ScriptBlock { Invoke-NativeCommand -Activity "Cloning $url" -Command $missing -TimeoutSeconds 30 } `
    -MessageLike (& $escape ("Cloning $shown failed: could not run $missingShown" +
            " ('$missingShown' is not an executable on PATH, and not the path to one.)")) `
    -Message 'and on a process of its own'

#───────────────────────────────────────────────────────────────────────────────
# Act
$noFolder = Invoke-NativeRead -Command $pwsh -WorkingDirectory 'https://u:SENTINEL@h.example/missing'

# Assert
Assert-Equal -Expected @('Working directory not found: https://***@h.example/missing') -Actual $noFolder.Output `
    -Message 'A working directory that is not there is named hidden'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a working directory on a provider other than the file system; no
# such provider holds a folder named like a credential, so the path lookup
# stands in for one
$onProbe = "-WorkingDirectory 'https://***@h.example/o' is on the Probe provider: give a folder on disk."

# Act / Assert
Assert-Throws `
    -ScriptBlock {
        & $module {
            function Test-Path { $true }
            function Resolve-Path { [PSCustomObject]@{ Provider = [PSCustomObject]@{ Name = 'Probe' } } }
            Invoke-NativeCapture -Command 'x' -WorkingDirectory 'https://u:SENTINEL@h.example/o'
        }
    } `
    -MessageLike (& $escape $onProbe) `
    -Message 'A working directory on another provider is named hidden'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws `
    -ScriptBlock { Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Environment @{ "$url=x" = '1' } } `
    -MessageLike (& $escape ("-Environment name '$shown=x' is not a valid variable name:" +
            " it must not be empty, blank, or contain '='.")) `
    -Message 'An -Environment name that cannot be a variable''s is named hidden'

exit (Complete-TestRun)
