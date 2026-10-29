using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

# Shared by this module's tests: a stand-in for Read-Host, a stand-in for the
# facts that say whether anyone can be asked, a stand-in for the User and
# Machine environment settings, and a real child PowerShell to watch the real
# Read-Host in. A test-only fixture - nothing here is exported. Dot-source it
# after importing the module.

# The CI variables Test-InteractiveHost looks at, read from the module itself;
# a test clears them so the machine it runs on cannot decide the outcome.
$script:CiVariableName = & (Get-Module TaffarelJr.UserInput) { $script:CiVariableName }
$script:SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'src')).Path
$script:HelperPath = $PSCommandPath

# A child process or runspace imports the real module, with no stand-in for
# the environment settings, so a script for one must not name a writer.
$script:WriterNamePattern = 'Set-EnvironmentVariable|Set-EnvironmentValue|SetEnvironmentVariable'
$script:WriterRefusal = 'a script that mentions Set-EnvironmentVariable, Set-EnvironmentValue or ' +
    'SetEnvironmentVariable is refused.'

function Install-FakeReadHost {
    <#
    .SYNOPSIS
        Replaces Read-Host with one that gives queued answers and remembers each
        prompt, so no test waits on a person.
    .DESCRIPTION
        Defined at global scope: the module's own call to Read-Host resolves by
        command lookup from the module, and a function in a test file's own
        scope is not visible from there when the file runs under the coverage
        wrapper. Each test file runs in its own process, so it never needs
        undoing. Asked with the queue empty, it throws rather than hang.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidGlobalVars',
        '',
        Justification = 'The test sets and reads the caller-session state the code under test uses.')]
    param()

    $global:FakeReadHostAnswers = [Queue[string]]::new()
    $global:FakeReadHostPrompts = [List[string]]::new()
    function global:Read-Host {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSAvoidGlobalVars',
            '',
            Justification = 'The test sets and reads the caller-session state the code under test uses.')]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSAvoidUsingConvertToSecureStringWithPlainText',
            '',
            Justification = 'A test builds a fake secret from a literal.')]
        param(
            [Parameter(Position = 0)]
            [string]$Prompt,

            [switch]$AsSecureString
        )

        $global:FakeReadHostPrompts.Add($Prompt)
        if ($global:FakeReadHostAnswers.Count -eq 0) {
            throw 'Read-Host was asked more often than the test gave answers.'
        }

        $answer = $global:FakeReadHostAnswers.Dequeue()
        if ($AsSecureString -and $answer -eq '') {
            return [securestring]::new()
        }

        if ($AsSecureString) {
            return ConvertTo-SecureString -String $answer -AsPlainText -Force
        }

        return $answer
    }
}

function Add-FakeAnswer {
    <#
    .SYNOPSIS
        Queues what the next Read-Host will be answered with.
    .PARAMETER Answer
        The answers, in the order they are given. An empty one is a bare Enter.
    .PARAMETER EndOfInput
        Queues the end of the input instead: the answer Read-Host gives when
        nothing more can be read, which is $null, not an empty string.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidGlobalVars',
        '',
        Justification = 'The test sets and reads the caller-session state the code under test uses.')]
    [CmdletBinding(DefaultParameterSetName = 'Answer')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ParameterSetName = 'Answer')]
        [AllowEmptyString()]
        [string[]]$Answer,

        [Parameter(Mandatory, ParameterSetName = 'EndOfInput')]
        [switch]$EndOfInput
    )

    process {
        if ($EndOfInput) {
            $global:FakeReadHostAnswers.Enqueue([NullString]::Value)
            return
        }

        foreach ($item in $Answer) {
            $global:FakeReadHostAnswers.Enqueue($item)
        }
    }
}

function Get-FakePrompt {
    <#
    .SYNOPSIS
        Returns every prompt Read-Host has been asked since Install-FakeReadHost.
    .OUTPUTS
        The prompts, one at a time.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidGlobalVars',
        '',
        Justification = 'The test sets and reads the caller-session state the code under test uses.')]
    param()

    return $global:FakeReadHostPrompts.ToArray()
}

function Use-FakeHost {
    <#
    .SYNOPSIS
        Makes the module believe this process was started a particular way, with
        no CI variable set.
    .PARAMETER Module
        The imported TaffarelJr.UserInput module.
    .PARAMETER UserInteractive
        What the host says about a user being present.
    .PARAMETER CommandLine
        The arguments the process was started with.
    .PARAMETER InputRedirected
        Says that input comes from a pipe or a file.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [bool]$UserInteractive = $true,

        [string[]]$CommandLine = @('pwsh'),

        [switch]$InputRedirected
    )

    foreach ($name in $script:CiVariableName) {
        [Environment]::SetEnvironmentVariable($name, $null)
    }

    & $Module {
        param($interactive, $line, $redirected)
        $script:FakeHostFact = [PSCustomObject]@{
            CommandLine     = $line
            UserInteractive = $interactive
            InputRedirected = $redirected
        }

        function script:Get-HostFact {
            return $script:FakeHostFact
        }
    } $UserInteractive $CommandLine ([bool]$InputRedirected)
}

function Get-ThrownError {
    <#
    .SYNOPSIS
        Runs a script block and returns the error it threw, for a test that has to
        look at more than its message - its category, say.
    .PARAMETER ScriptBlock
        The code to run.
    .OUTPUTS
        The ErrorRecord, or $null when nothing was thrown.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    try {
        $null = & $ScriptBlock
    }
    catch {
        return $_
    }

    return $null
}

function Use-FakeEnvironmentStore {
    <#
    .SYNOPSIS
        Gives the module an empty stand-in for the User and Machine environment
        settings, so no test ever changes the real ones.
    .DESCRIPTION
        This process's own variables are still the real ones: a test can set
        and clear them freely, and they go away with the process. Throws,
        before any test can run, when Assert-FakeEnvironmentStore finds a way
        around the stand-in.
    .PARAMETER Module
        The imported TaffarelJr.UserInput module.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module
    )

    & $Module {
        $script:FakeEnvironment = [Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
        $script:FakeFailFor = $null

        function script:Get-EnvironmentValue {
            param($Name, $Target)

            if ($script:FakeFailFor -and $Name -eq $script:FakeFailFor) {
                throw "The settings for $Name could not be read."
            }

            if ($Target -eq 'Process') {
                return [Environment]::GetEnvironmentVariable($Name)
            }

            $value = $null
            $null = $script:FakeEnvironment.TryGetValue("$Target|$Name", [ref]$value)
            return $value
        }

        function script:Set-EnvironmentValue {
            param($Name, $Value, $Target)

            if ($script:FakeFailFor -and $Name -eq $script:FakeFailFor) {
                throw "The settings for $Name could not be written."
            }

            if ($Target -eq 'Process') {
                [Environment]::SetEnvironmentVariable($Name, $Value)
                return
            }

            if ([string]::IsNullOrEmpty($Value)) {
                $null = $script:FakeEnvironment.Remove("$Target|$Name")
                return
            }

            $script:FakeEnvironment["$Target|$Name"] = $Value
        }
    }

    Assert-FakeEnvironmentStore -Module $Module
}

function Set-FakeStoreFailure {
    <#
    .SYNOPSIS
        Makes the stand-in settings fail every read and write of one variable,
        in any scope.
    .PARAMETER Module
        The imported TaffarelJr.UserInput module, after Use-FakeEnvironmentStore.
    .PARAMETER Name
        The variable whose reads and writes fail. None clears it.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [string]$Name
    )

    & $Module {
        param($failFor)
        $script:FakeFailFor = $failFor
    } $Name
}
function Assert-FakeEnvironmentStore {
    <#
    .SYNOPSIS
        Throws unless the module's writes to the User and Machine environment
        settings go to the stand-in.
    .DESCRIPTION
        Only looks at the module - it never calls a writer, so it is safe to
        run on a module whose stand-in is missing. It checks that
        Set-EnvironmentValue, as the module resolves it, is the stand-in this
        file defines; that Set-EnvironmentVariable calls Set-EnvironmentValue;
        and that no other function of the module, nor its root script, has a
        writer of its own: a SetEnvironmentVariable( call, setx, the registry
        (HKCU:, HKLM:, HKEY_, Registry::, Microsoft.Win32.Registry), or an
        ItemProperty cmdlet. That last check reads the text, so a writer that
        hides its name gets past it; the first two are what keep
        Set-EnvironmentVariable itself off the real settings.
    .PARAMETER Module
        The imported TaffarelJr.UserInput module.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module
    )

    $writerPattern = 'SetEnvironmentVariable\s*\(|\bsetx\b|HKCU:|HKLM:|HKEY_|Registry::|Win32\.Registry|-ItemProperty\b'
    $unsafe = & $Module {
        param($helperPath, $pattern)

        $seam = Get-Command -Name Set-EnvironmentValue -CommandType Function
        if ($seam.ScriptBlock.File -ne $helperPath) {
            'Set-EnvironmentValue (it is not the stand-in)'
        }

        $writer = Get-Command -Name Set-EnvironmentVariable -CommandType Function
        $calls = $writer.ScriptBlock.Ast.FindAll({ param($node) $node -is [CommandAst] }, $true)
        $called = foreach ($call in $calls) {
            $call.GetCommandName()
        }

        if ($called -notcontains 'Set-EnvironmentValue') {
            'Set-EnvironmentVariable (it does not write through Set-EnvironmentValue)'
        }

        $functions = Get-ChildItem -Path function:
        foreach ($function in $functions) {
            $other = $function.ModuleName -eq 'TaffarelJr.UserInput' -and $function.Name -ne 'Set-EnvironmentValue'
            if ($other -and $function.Definition -match $pattern) {
                $function.Name
            }
        }
    } $script:HelperPath $writerPattern

    $rootScript = Get-Content -LiteralPath $Module.Path -Raw
    if ($rootScript -match $writerPattern) {
        $unsafe = @($unsafe) + "the root script $(Split-Path -Leaf $Module.Path)"
    }

    if ($unsafe) {
        throw "Use-FakeEnvironmentStore: these could write the real environment settings, so no test runs: $($unsafe -join ', ')."
    }
}

function Set-FakeStoredValue {
    <#
    .SYNOPSIS
        Puts a value in the stand-in User or Machine settings.
    .PARAMETER Module
        The imported TaffarelJr.UserInput module, after Use-FakeEnvironmentStore.
    .PARAMETER Name
        The variable.
    .PARAMETER Value
        What it holds.
    .PARAMETER Target
        User or Machine.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory)]
        [ValidateSet('User', 'Machine')]
        [string]$Target
    )

    & $Module {
        param($n, $v, $t)
        $script:FakeEnvironment["$t|$n"] = $v
    } $Name $Value $Target
}

function Get-FakeStoredValue {
    <#
    .SYNOPSIS
        Returns what the stand-in User or Machine settings hold for a variable.
    .PARAMETER Module
        The imported TaffarelJr.UserInput module, after Use-FakeEnvironmentStore.
    .PARAMETER Name
        The variable.
    .PARAMETER Target
        User or Machine.
    .OUTPUTS
        The value, or nothing when the variable is not there.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('User', 'Machine')]
        [string]$Target
    )

    return & $Module {
        param($n, $t)
        $value = $null
        if ($script:FakeEnvironment.TryGetValue("$t|$n", [ref]$value)) {
            return $value
        }
    } $Name $Target
}

function Invoke-WithConsoleInput {
    <#
    .SYNOPSIS
        Runs a script block with this process's console input replaced by
        the given text, then puts the real input back.
    .PARAMETER Text
        What the input holds. Empty is input that is already at its end.
    .PARAMETER ScriptBlock
        The code to run.
    .OUTPUTS
        Whatever the script block returns.
    #>
    param(
        [AllowEmptyString()]
        [string]$Text = '',

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $original = [Console]::In
    [Console]::SetIn([IO.StringReader]::new($Text))
    try {
        return (& $ScriptBlock)
    }
    finally {
        [Console]::SetIn($original)
    }
}

function Measure-HostlessRetry {
    <#
    .SYNOPSIS
        Runs a block through Invoke-InputRetry in a runspace with no host, and
        returns how many attempts it took and how the last one failed.
    .DESCRIPTION
        With no host, a missing mandatory parameter fails instead of prompting
        for a value, so a test can watch it without waiting on a person. The
        runspace imports its own copy of the module, which is told a person is
        present. A run still going after the timeout is stopped.
        That copy has no stand-in for the User and Machine environment
        settings, so a script that names a writer of them is refused before
        the runspace starts.
    .PARAMETER Script
        The block's text. It may define functions before using them. It must
        not mention Set-EnvironmentVariable, Set-EnvironmentValue or
        SetEnvironmentVariable.
    .PARAMETER TimeoutSeconds
        How long to wait.
    .OUTPUTS
        A PSCustomObject with Attempts and ErrorId (the last failure's
        FullyQualifiedErrorId, or an empty string when it succeeded).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidGlobalVars',
        '',
        Justification = 'The test sets and reads the caller-session state the code under test uses.')]
    param(
        [Parameter(Mandatory)]
        [string]$Script,

        [int]$TimeoutSeconds = 60
    )

    if ($Script -match $script:WriterNamePattern) {
        throw "Measure-HostlessRetry: the runspace has no stand-in for the environment settings, so $script:WriterRefusal"
    }

    $runner = {
        param($sourceRoot, $script)
        Import-Module (Join-Path $sourceRoot 'TaffarelJr.ConsoleOutput' 'TaffarelJr.ConsoleOutput.psd1')
        $module = Import-Module (Join-Path $sourceRoot 'TaffarelJr.UserInput' 'TaffarelJr.UserInput.psd1') -PassThru
        & $module {
            function script:Get-HostFact {
                return [PSCustomObject]@{
                    CommandLine     = @('pwsh')
                    UserInteractive = $true
                    InputRedirected = $false
                }
            }
        }

        $block = [scriptblock]::Create($script)
        $global:HostlessAttempts = 0
        $errorId = ''
        try {
            $null = Invoke-InputRetry -ScriptBlock {
                $global:HostlessAttempts++
                & $block
            }
        }
        catch {
            $errorId = $_.FullyQualifiedErrorId
        }

        [PSCustomObject]@{
            Attempts = $global:HostlessAttempts
            ErrorId  = $errorId
        }
    }

    $shell = [powershell]::Create()
    try {
        $null = $shell.AddScript($runner).AddArgument($script:SourceRoot).AddArgument($Script)
        $pending = $shell.BeginInvoke()
        if (-not $pending.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000)) {
            $shell.Stop()
            throw "Measure-HostlessRetry: the block was still running after $TimeoutSeconds seconds"
        }

        return $shell.EndInvoke($pending)[0]
    }
    finally {
        $shell.Dispose()
    }
}

function Invoke-ChildPowerShell {
    <#
    .SYNOPSIS
        Runs a script in a new PowerShell with this module loaded, and returns
        what it printed and how it ended.
    .DESCRIPTION
        For watching the real Read-Host, which a test cannot do from inside the
        process it is deciding about. The child gets exactly the standard input
        given - none at all means it is closed at once - and no CI variable
        unless -Environment adds one. A child that is still running after the
        timeout is killed.
        The child imports the real module, with no stand-in for the User and
        Machine environment settings, so a script that names a writer of them
        is refused before the child starts.
    .PARAMETER Script
        What to run, after the module is imported. It must not mention
        Set-EnvironmentVariable, Set-EnvironmentValue or
        SetEnvironmentVariable.
    .PARAMETER Flag
        Launch options, such as -NonInteractive.
    .PARAMETER StdIn
        Lines to feed to its standard input.
    .PARAMETER Environment
        Variables to set for it.
    .PARAMETER TimeoutSeconds
        How long to wait.
    .OUTPUTS
        A PSCustomObject with ExitCode, Output (stdout and stderr, as one
        string), and TimedOut.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Script,

        [string[]]$Flag = @(),

        [string[]]$StdIn = @(),

        [hashtable]$Environment = @{},

        [int]$TimeoutSeconds = 60
    )

    if ($Script -match $script:WriterNamePattern) {
        throw "Invoke-ChildPowerShell: the child has no stand-in for the environment settings, so $script:WriterRefusal"
    }

    $manifest = Join-Path $script:SourceRoot 'TaffarelJr.UserInput' 'TaffarelJr.UserInput.psd1'
    $info = [ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    $arguments = @('-NoProfile') + $Flag + @('-Command', "Import-Module '$manifest'; $Script")
    foreach ($argument in $arguments) {
        $info.ArgumentList.Add($argument)
    }

    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.Environment['PSModulePath'] = $script:SourceRoot + [IO.Path]::PathSeparator + $env:PSModulePath
    foreach ($name in $script:CiVariableName) {
        $null = $info.Environment.Remove($name)
    }

    foreach ($name in $Environment.Keys) {
        $info.Environment[$name] = $Environment[$name]
    }

    $process = [Process]::Start($info)
    foreach ($line in $StdIn) {
        $process.StandardInput.WriteLine($line)
    }

    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }

    return [PSCustomObject]@{
        ExitCode = $process.ExitCode
        Output   = (($stdout.Result + $stderr.Result) -replace "`r", '')
        TimedOut = $timedOut
    }
}
