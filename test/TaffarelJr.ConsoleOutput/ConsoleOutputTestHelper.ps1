using namespace System.Management.Automation

# Shared by this module's tests: a clean slate for the module's ambient state,
# a stand-in for the host's window width, and a capture that keeps each
# message's color. A test-only fixture - nothing here is exported.

function Reset-ConsoleOutputState {
    <#
    .SYNOPSIS
        Puts the module's indent, open line, and step count back to their start.
    .PARAMETER Module
        The imported TaffarelJr.ConsoleOutput module.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module
    )

    & $Module {
        $script:IndentStack.Clear()
        $script:LineOpen = $false
        $script:StepNumber = 0
        $script:CurrentStepLabel = ''
    }
}

function Use-FakeHostWidth {
    <#
    .SYNOPSIS
        Replaces the module's host-width reading, so a test chooses how wide
        the console is - or that there is none.
    .DESCRIPTION
        Each test file runs in its own process, so the replacement never needs
        undoing. Call it again to change the width.
    .PARAMETER Module
        The imported TaffarelJr.ConsoleOutput module.
    .PARAMETER Width
        What the host reports. 0 is what a host with no window reports.
    .PARAMETER Throw
        Makes the host fail the way one with no window can.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [int]$Width = 80,

        [switch]$Throw
    )

    & $Module {
        param($width, $shouldThrow)
        $script:FakeHostWidth = $width
        $script:FakeHostWidthShouldThrow = $shouldThrow
        function script:Get-HostWidth {
            if ($script:FakeHostWidthShouldThrow) {
                throw 'there is no window'
            }

            return $script:FakeHostWidth
        }
    } $Width $Throw
}

function Use-FakeOutputRedirect {
    <#
    .SYNOPSIS
        Replaces the module's check for redirected output, so a test chooses
        whether output goes to a file or a pipe instead of a console.
    .DESCRIPTION
        Each test file runs in its own process, so the replacement never needs
        undoing. Call it again to change the answer.
    .PARAMETER Module
        The imported TaffarelJr.ConsoleOutput module.
    .PARAMETER Redirected
        What the check reports.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [Parameter(Mandatory)]
        [bool]$Redirected
    )

    & $Module {
        param($redirected)
        $script:FakeOutputRedirected = $redirected
        function script:Test-OutputRedirected {
            return $script:FakeOutputRedirected
        }
    } $Redirected
}

function Get-HostMessage {
    <#
    .SYNOPSIS
        Runs a script block and returns each Write-Host call it made, with the
        color and whether it left its line open.
    .PARAMETER ScriptBlock
        The code to run and capture.
    .OUTPUTS
        One object per call - Message, Color (as text), NoNewLine - one at a
        time. Wrap the call in @() to collect them as an array.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $records = & $ScriptBlock 6>&1
    foreach ($record in $records) {
        if ($record -isnot [InformationRecord] -or $record.MessageData -isnot [HostInformationMessage]) {
            continue
        }

        $data = $record.MessageData
        [PSCustomObject]@{
            Message   = $data.Message
            Color     = "$($data.ForegroundColor)"
            NoNewLine = [bool]$data.NoNewLine
        }
    }
}
