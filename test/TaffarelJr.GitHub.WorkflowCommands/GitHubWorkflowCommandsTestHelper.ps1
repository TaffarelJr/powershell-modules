using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.IO
using namespace System.Text
using namespace System.Text.RegularExpressions

$script:ModuleManifest = Join-Path $PSScriptRoot '..' '..' 'src' 'TaffarelJr.GitHub.WorkflowCommands' 'TaffarelJr.GitHub.WorkflowCommands.psd1'
$script:SourceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..' 'src')).Path
$script:DependencyManifest = Join-Path $script:SourceRoot 'TaffarelJr.ProcessInvocation' `
    'TaffarelJr.ProcessInvocation.psd1'

function Install-FakeLineWriter {
    <#
    .SYNOPSIS
        Replaces the module's line writer with one that keeps each line
        instead of sending it to the process's standard output.
    .DESCRIPTION
        Each test file runs in its own process, so the replacement never needs
        undoing. Calling it again forgets the lines kept so far.
    #>
    [CmdletBinding()]
    param()

    & (Get-Module -Name 'TaffarelJr.GitHub.WorkflowCommands') {
        $script:WrittenLines = [System.Collections.Generic.List[string]]::new()
        function script:Write-GitHubActionsLine {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)]
                [AllowEmptyString()]
                [string]$Line
            )

            $script:WrittenLines.Add($Line)
        }
    }
}

function Get-WrittenLine {
    <#
    .SYNOPSIS
        Returns every line the fake line writer has kept since
        Install-FakeLineWriter.
    .OUTPUTS
        Each line, one at a time. Wrap the call in @() to collect them.
    #>
    [CmdletBinding()]
    param()

    return & (Get-Module -Name 'TaffarelJr.GitHub.WorkflowCommands') { $script:WrittenLines.ToArray() }
}

function Get-WorkflowCommand {
    <#
    .SYNOPSIS
        Runs a script block and returns the workflow command lines it wrote.
    .DESCRIPTION
        The block runs in a scope of its own, and any pipeline output of it is
        discarded; for a test of either, call Install-FakeLineWriter and
        Get-WrittenLine around the code instead.
    .PARAMETER ScriptBlock
        The code to run.
    .OUTPUTS
        Each line, one at a time. Wrap the call in @() to collect them.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    Install-FakeLineWriter
    $null = & $ScriptBlock
    return Get-WrittenLine
}

function New-WorkflowCommandsSandbox {
    <#
    .SYNOPSIS
        Creates an empty folder under the temp folder for one test file to
        work in.
    .OUTPUTS
        The folder's full path.
    #>
    [CmdletBinding()]
    param()

    $path = Join-Path ([Path]::GetTempPath()) "workflowcommands-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function New-CommandFile {
    <#
    .SYNOPSIS
        Creates an empty runner file and points its GITHUB_* variable at it,
        as the runner does before each step.
    .PARAMETER Variable
        The variable, such as GITHUB_OUTPUT.
    .PARAMETER Directory
        The folder to create the file in.
    .PARAMETER Name
        The file's name. Defaults to the variable's name.
    .OUTPUTS
        The file's full path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Variable,

        [Parameter(Mandatory)]
        [string]$Directory,

        [string]$Name = $Variable
    )

    $path = Join-Path $Directory $Name
    [File]::WriteAllBytes($path, [byte[]]@())
    [Environment]::SetEnvironmentVariable($Variable, $path)
    return $path
}

function Read-CommandFileEntry {
    <#
    .SYNOPSIS
        Reads back every name/value pair in a GITHUB_OUTPUT, GITHUB_ENV, or
        GITHUB_STATE file, as the runner does.
    .DESCRIPTION
        Reads the bytes as UTF-8 without dropping a byte order mark, so a
        file that starts with one gives a first name that starts with it.
        Throws for anything that is not a sequence of heredoc entries.
    .PARAMETER Path
        The file.
    .OUTPUTS
        One object per entry - Name, Value - one at a time.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $text = [UTF8Encoding]::new($false).GetString([File]::ReadAllBytes($Path))
    $pattern = '\G(?<name>[^\n]*?)<<(?<delimiter>ghadelimiter_[0-9a-f-]{36})\n(?<value>.*?)\n\k<delimiter>\n'
    $entries = [regex]::Matches($text, $pattern, [RegexOptions]::Singleline)
    $consumed = 0
    foreach ($entry in $entries) {
        $consumed += $entry.Length
    }

    if ($consumed -ne $text.Length) {
        throw "'$Path' is not a sequence of heredoc entries: $text"
    }

    foreach ($entry in $entries) {
        [PSCustomObject]@{
            Name  = $entry.Groups['name'].Value
            Value = $entry.Groups['value'].Value
        }
    }
}

function Invoke-ChildPowerShell {
    <#
    .SYNOPSIS
        Runs a script in a new PowerShell with this module loaded, and returns
        what it wrote to its standard output.
    .DESCRIPTION
        For watching what really reaches the process's standard output, which
        a test cannot see from inside the process writing it. The output is
        read as UTF-8 bytes, whatever the child's console encoding. A child
        still running after the timeout is killed.
    .PARAMETER Script
        What to run, after the module is imported.
    .PARAMETER TimeoutSeconds
        How long to wait.
    .PARAMETER Environment
        Environment variables to set for the child, on top of this process's.
    .OUTPUTS
        A PSCustomObject with ExitCode, Lines (each standard output line),
        Error (the standard error text), and TimedOut.

        The child imports the module and the one it requires by the path of
        their manifests, so a slow search of its PSModulePath cannot eat the
        timeout. Any other runspace it starts finds the modules of this repo
        by name, as RequiredModules asks: its PSModulePath has the repo's src
        folder in front.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Script,

        [int]$TimeoutSeconds = 180,

        [hashtable]$Environment = @{}
    )

    $manifest = (Resolve-Path -LiteralPath $script:ModuleManifest).Path
    $dependency = (Resolve-Path -LiteralPath $script:DependencyManifest).Path
    $info = [ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    foreach ($name in $Environment.PSBase.Keys) {
        $info.Environment[$name] = $Environment[$name]
    }

    $info.Environment['PSModulePath'] = $script:SourceRoot + [Path]::PathSeparator + $env:PSModulePath

    $arguments = @(
        '-NoProfile'
        '-NonInteractive'
        '-Command'
        "`$ErrorActionPreference = 'Stop'; Import-Module '$dependency'; Import-Module '$manifest'; $Script"
    )
    foreach ($argument in $arguments) {
        $info.ArgumentList.Add($argument)
    }

    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [UTF8Encoding]::new($false)
    $process = [Process]::Start($info)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }

    $lines = [List[string]]::new()
    foreach ($line in ($stdout.Result -split '\r?\n')) {
        if ($line) {
            $lines.Add($line)
        }
    }

    return [PSCustomObject]@{
        ExitCode = $process.ExitCode
        Lines    = $lines.ToArray()
        Error    = $stderr.Result
        TimedOut = $timedOut
    }
}

function Invoke-OutOfProcessScript {
    <#
    .SYNOPSIS
        Runs a script in a runspace in another PowerShell process with this
        module loaded, as a background job does, and reports what came back.
    .DESCRIPTION
        That process's standard output carries the runspace's own messages,
        so a raw line written to it breaks the runspace. The process is
        ended afterwards, whatever happened.
    .PARAMETER Script
        What to run, after the module is imported.
    .PARAMETER TimeoutSeconds
        How long to wait for the script.
    .OUTPUTS
        A PSCustomObject with State (the invocation's), RunspaceState,
        Output (each output object's text), and Information (each
        information record's text).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Script,

        [int]$TimeoutSeconds = 120
    )

    $manifest = (Resolve-Path -LiteralPath $script:ModuleManifest).Path
    $savedModulePath = $env:PSModulePath
    $env:PSModulePath = $script:SourceRoot + [Path]::PathSeparator + $env:PSModulePath
    $process = [System.Management.Automation.Runspaces.PowerShellProcessInstance]::new()
    $remote = [runspacefactory]::CreateOutOfProcessRunspace($null, $process)
    try {
        $remote.Open()
        $shell = [powershell]::Create()
        $shell.Runspace = $remote
        $null = $shell.AddScript("Import-Module '$manifest'; $Script")
        $output = [System.Management.Automation.PSDataCollection[psobject]]::new()
        $none = [System.Management.Automation.PSDataCollection[psobject]]::new()
        $async = $shell.BeginInvoke($none, $output)
        $null = $async.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000)
        $information = [List[string]]::new()
        foreach ($record in $shell.Streams.Information) {
            $information.Add("$($record.MessageData)")
        }

        $texts = [List[string]]::new()
        foreach ($item in $output) {
            $texts.Add("$item")
        }

        return [PSCustomObject]@{
            State         = "$($shell.InvocationStateInfo.State)"
            RunspaceState = "$($remote.RunspaceStateInfo.State)"
            Output        = $texts.ToArray()
            Information   = $information.ToArray()
        }
    }
    finally {
        $env:PSModulePath = $savedModulePath
        $remote.Dispose()
        if ($null -ne $process.Process -and -not $process.Process.HasExited) {
            $process.Process.Kill()
        }

        $process.Dispose()
    }
}

function Get-MaskReport {
    <#
    .SYNOPSIS
        Checks a log in which values were masked and then printed as
        "deploying with <value>", as the runner would read it.
    .PARAMETER Line
        The log's lines, in order.
    .OUTPUTS
        A PSCustomObject with Torn (each line holding an add-mask that does
        not start it), Unmasked (each line printing a value before its mask),
        and Masked (how many values were masked).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Line
    )

    $torn = [List[string]]::new()
    $unmasked = [List[string]]::new()
    $masked = [HashSet[string]]::new()
    foreach ($text in $Line) {
        if ($text.StartsWith('::add-mask::')) {
            $null = $masked.Add($text.Substring('::add-mask::'.Length))
            continue
        }

        if ($text.Contains('::add-mask::')) {
            $torn.Add($text)
        }

        foreach ($match in [regex]::Matches($text, 'deploying with (fake-secret-\d+-\d+)')) {
            if (-not $masked.Contains($match.Groups[1].Value)) {
                $unmasked.Add($text)
            }
        }
    }

    return [PSCustomObject]@{
        Torn     = $torn.ToArray()
        Unmasked = $unmasked.ToArray()
        Masked   = $masked.Count
    }
}
