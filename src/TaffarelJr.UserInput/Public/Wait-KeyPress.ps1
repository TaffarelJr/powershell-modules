function Wait-KeyPress {
    <#
    .SYNOPSIS
        Pauses until a key is pressed - "press any key to continue."
    .DESCRIPTION
        Skips immediately, printing nothing,
        when Test-InteractiveHost reports there is nobody to press anything:
        PowerShell's own built-in Pause (a Read-Host under the hood)
        would otherwise block forever in that case,
        waiting on a person who was never there.
    .PARAMETER Message
        Shown before waiting. Defaults to "Press any key to continue...".
    #>
    param(
        [string]$Message = 'Press any key to continue...'
    )

    if (-not (Test-InteractiveHost)) {
        return
    }

    Write-Host $Message -NoNewline
    $null = [Console]::ReadKey($true)
    Write-Host ''
}
