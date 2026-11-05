#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
. (Join-Path $PSScriptRoot 'ProcessInvocationTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

# A command of another module that calls Invoke-NativeCommand and Invoke-NativeRead, the way the
# modules built on this one do, so what the caller asked for has to cross a module boundary.
$null = New-Module -Name ProcessInvocationCaller -ScriptBlock {
    function Invoke-CallerCommand {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Program
        )

        Invoke-NativeCommand -Activity 'Calling' -Command $Program -Argument @('-NoProfile', '-Command', 'exit 0')
    }

    function Invoke-CallerRead {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [string]$Program
        )

        $null = Invoke-NativeRead -Command $Program -Argument @('-NoProfile', '-Command', 'exit 0')
    }
} | Import-Module

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a call with -Verbose
$lines = @(Get-VerboseLine {
        Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 0') -Verbose
    })

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'Invoke-NativeCommand says once what it is about to run'
Assert-That -Condition ($lines[0] -like "Running: & '*' -NoProfile -Command 'exit 0'") `
    -Message 'as the command line, quoted so it can be pasted back'
Assert-That -Condition ($lines[0].Contains($pwsh)) -Message 'with the program that will run'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the same call with no -Verbose
$quiet = @(Get-VerboseLine {
        Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 0')
    })

# Assert
Assert-Equal -Expected @() -Actual $quiet -Message 'Without -Verbose it says nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - Invoke-NativeRead with -Verbose
$readLines = @(Get-VerboseLine {
        $null = Invoke-NativeRead -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 0') -Verbose
    })

# Assert
Assert-Equal -Expected 1 -Actual $readLines.Count -Message 'Invoke-NativeRead says once what it is about to run'
Assert-That -Condition ($readLines[0] -like "Running: & '*' -NoProfile -Command 'exit 0'") `
    -Message 'in the same form'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a PowerShell command, given a URL that carries a credential
function global:Invoke-VerboseProbe { $global:LASTEXITCODE = 0 }
$url = 'https://x-access-token:SENTINEL@h.example/o/r'

# Act
$hiddenLines = @(Get-VerboseLine {
        Invoke-NativeCommand -Activity 'Testing' -Command 'Invoke-VerboseProbe' -Argument @($url) -Verbose
    })
Remove-Item -Path function:global:Invoke-VerboseProbe

# Assert
Assert-That -Condition ($hiddenLines[0].Contains('https://***@h.example/o/r')) `
    -Message 'The credential a URL carries is hidden in the line'
Assert-That -Condition (-not $hiddenLines[0].Contains('SENTINEL')) -Message 'and appears nowhere in it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that must never be printed: what goes to standard input, and an environment
$secretIn = 'STDIN-SENTINEL'
$secretEnv = @{ PROBE_TOKEN = 'ENV-SENTINEL' }

# Act
$secretLines = @(Get-VerboseLine {
        Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Verbose -StdIn $secretIn -Environment $secretEnv `
            -Argument @('-NoProfile', '-Command', 'exit 0')
    })

# Assert
Assert-Equal -Expected 1 -Actual $secretLines.Count -Message 'A call that runs the program directly says it once too'
Assert-That -Condition (-not $secretLines[0].Contains('STDIN-SENTINEL')) -Message 'It never shows what is sent to standard input'
Assert-That -Condition (-not $secretLines[0].Contains('ENV-SENTINEL')) -Message 'or an environment value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a working directory, which the line names
$folderLines = @(Get-VerboseLine {
        Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Verbose -WorkingDirectory $PSScriptRoot `
            -Argument @('-NoProfile', '-Command', 'exit 0')
    })

# Assert
Assert-That -Condition ($folderLines[0].EndsWith(" (in $PSScriptRoot)")) -Message 'The line ends with the folder the command runs in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a command of another module that was itself given -Verbose
$crossed = @(Get-VerboseLine { Invoke-CallerCommand -Program $pwsh -Verbose })
$crossedRead = @(Get-VerboseLine { Invoke-CallerRead -Program $pwsh -Verbose })

# Assert
Assert-Equal -Expected 1 -Actual $crossed.Count `
    -Message 'A call made for another module shows the line when that module''s command was given -Verbose'
Assert-Equal -Expected 1 -Actual $crossedRead.Count -Message 'and so does a read'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the same command, with no -Verbose
$crossedQuiet = @(Get-VerboseLine { Invoke-CallerCommand -Program $pwsh })

# Assert
Assert-Equal -Expected @() -Actual $crossedQuiet -Message 'Without -Verbose it stays quiet across the boundary too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a session that asks for verbose output everywhere
$global:VerbosePreference = 'Continue'
try {
    # Act
    $session = @(Get-VerboseLine { Invoke-CallerCommand -Program $pwsh })
    $declined = @(Get-VerboseLine { Invoke-CallerCommand -Program $pwsh -Verbose:$false })
    $declinedHere = @(Get-VerboseLine {
            Invoke-NativeCommand -Activity 'Testing' -Command $pwsh -Argument @('-NoProfile', '-Command', 'exit 0') -Verbose:$false
        })
}
finally {
    $global:VerbosePreference = 'SilentlyContinue'
}

# Assert
Assert-Equal -Expected 1 -Actual $session.Count -Message 'A $VerbosePreference of Continue in the caller reaches the line'
Assert-Equal -Expected @() -Actual $declined -Message 'but -Verbose:$false on the caller''s command turns it off'
Assert-Equal -Expected @() -Actual $declinedHere -Message 'and so does -Verbose:$false on the call itself'

exit (Complete-TestRun)
