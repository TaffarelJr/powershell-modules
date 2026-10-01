function Wait-KeyPress {
    <#
    .SYNOPSIS
        Pauses until a key is pressed - "press any key to continue."
    .DESCRIPTION
        Skips immediately, printing nothing,
        when there is nobody to press anything:
        when Test-InteractiveHost says so (on CI, for one), or when input is
        redirected, since a key cannot be read from a pipe or a file.
        PowerShell's own built-in Pause (a Read-Host under the hood)
        would otherwise sit waiting on a CI runner's terminal
        for a person who was never there.
    .PARAMETER Message
        Shown before waiting. Defaults to "Press any key to continue...".
    .INPUTS
        None. Nothing can be piped in.
    .OUTPUTS
        None. The message is shown on the console.
    .EXAMPLE
        Wait-KeyPress

        Shows "Press any key to continue..." and waits, where a person is
        there to press one.
    .EXAMPLE
        Wait-KeyPress -Message 'Press any key to close this window...'

        Waits with a message of its own.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Test-InteractiveHost
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock',
        '',
        Justification = 'A console that went away leaves nobody to wait for.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Shows the prompt to the person at the console; it is not data.')]
    param(
        [string]$Message = 'Press any key to continue...'
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not (Test-InteractiveHost) -or (Get-HostFact).InputRedirected) {
            return
        }

        Write-Host $Message -NoNewline
        try {
            Read-KeyPress
        }
        catch [InvalidOperationException] {
            # The console went away between the check and the read: nobody to wait for.
        }

        Write-Host ''
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
