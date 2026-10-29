#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')
$module = Get-Module TaffarelJr.UserInput

# A stand-in for the key read, which counts calls, so no test here waits for a
# key or needs a console.
& $module {
    $script:KeyReads = 0
    $script:KeyReadError = $null
    function script:Read-KeyPress {
        $script:KeyReads++
        if ($null -ne $script:KeyReadError) {
            throw $script:KeyReadError
        }
    }
}

function Get-KeyReadCount {
    & $module { $script:KeyReads }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nobody to press a key
Use-FakeHost -Module $module -UserInteractive $false

# Act
$lines = @(Get-HostOutput { Wait-KeyPress })
$custom = @(Get-HostOutput { Wait-KeyPress -Message 'Custom message' })

# Assert
Assert-Equal -Expected 0 -Actual $lines.Count -Message 'Wait-KeyPress prints nothing when the host is not interactive'
Assert-Equal -Expected 0 -Actual $custom.Count -Message 'and so does a custom -Message'
Assert-Equal -Expected 0 -Actual (Get-KeyReadCount) -Message 'It never waits for a key'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a session that looks interactive, but whose input is a pipe or a file
Use-FakeHost -Module $module -InputRedirected

# Act
$redirected = @(Get-HostOutput { Wait-KeyPress })

# Assert
Assert-Equal -Expected 0 -Actual $redirected.Count `
    -Message 'Redirected input prints nothing either, since a key cannot be read from it'
Assert-Equal -Expected 0 -Actual (Get-KeyReadCount) -Message 'and it does not try'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a person at a console
Use-FakeHost -Module $module

# Act
$interactive = @(Get-HostOutput { Wait-KeyPress })
$withMessage = @(Get-HostOutput { Wait-KeyPress -Message 'Any key, please' })

# Assert
Assert-Equal -Expected @('Press any key to continue...', '') -Actual $interactive `
    -Message 'The default message is shown, and the line is ended once the key is pressed'
Assert-Equal -Expected @('Any key, please', '') -Actual $withMessage -Message 'A custom -Message replaces it'
Assert-Equal -Expected 2 -Actual (Get-KeyReadCount) -Message 'Each call waits for exactly one key'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the console goes away between the check and the read
Use-FakeHost -Module $module
& $module { $script:KeyReadError = [InvalidOperationException]::new('there is no console') }

# Act
$lost = @(Get-HostOutput { Wait-KeyPress })

# Assert
Assert-Equal -Expected @('Press any key to continue...', '') -Actual $lost `
    -Message 'A key that cannot be read ends the wait instead of failing the script'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the key read fails for some other reason
Use-FakeHost -Module $module
& $module { $script:KeyReadError = [IO.IOException]::new('the device broke') }

# Act / Assert
Assert-Throws -ScriptBlock {
    $null = Get-HostOutput { Wait-KeyPress }
} -MessageLike 'the device broke' -Message 'Any other failure of the key read is not swallowed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - real processes with nobody to press a key
$closed = Invoke-ChildPowerShell -Script "Wait-KeyPress; 'done'"
$piped = Invoke-ChildPowerShell -Script "Wait-KeyPress; 'done'" -StdIn 'x'

# Assert
Assert-Equal -Expected $false -Actual $closed.TimedOut -Message 'A real session whose input is closed does not wait'
Assert-Equal -Expected 'done' -Actual $closed.Output.Trim() -Message 'and carries on without printing anything'
Assert-Equal -Expected $false -Actual $piped.TimedOut -Message 'nor does one whose input is piped'
Assert-Equal -Expected 'done' -Actual $piped.Output.Trim() -Message 'which carries on the same way'

exit (Complete-TestRun)
