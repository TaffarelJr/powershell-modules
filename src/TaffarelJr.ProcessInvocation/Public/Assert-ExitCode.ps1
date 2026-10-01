function Assert-ExitCode {
    <#
    .SYNOPSIS
        Throws when an exit code is non-zero.
    .DESCRIPTION
        For a command whose own output was already allowed
        to stream straight to the console, rather than being captured.
        Invoke-NativeCommand is the better fit
        when the output is only interesting on failure;
        this is for when it was already shown either way,
        and only the final verdict is still needed.
    .PARAMETER Name
        What was being attempted, named in the thrown message.
    .PARAMETER ExitCode
        Defaults to $LASTEXITCODE,
        so the common case is just Assert-ExitCode 'Build'
        right after the native call it is checking.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [int]$ExitCode = $LASTEXITCODE
    )

    if ($ExitCode -eq 0) {
        return
    }

    throw "$Name failed with exit code $ExitCode"
}
