function Get-HostWidth {
    <#
    .SYNOPSIS
        Returns the host window's width, or 0 when there is no window to
        measure.
    .DESCRIPTION
        Not exported. Returns 0 when the process's standard output is
        redirected: a log written to a file should not take the width of
        whatever window happened to run it. Redirecting a PowerShell stream
        inside the session (*> log.txt) leaves standard output on the console,
        so the window's width is kept. A host with no window, such as a
        runspace created with [powershell]::Create(), reports no window size,
        which comes back as 0 too.
        Kept apart from Get-ConsoleWidth so a test can stand in for a host
        that is wide, narrow, or absent.
    .OUTPUTS
        The width in columns, or 0.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    if (Test-OutputRedirected) {
        return 0
    }

    $size = $Host.UI.RawUI.WindowSize
    if ($null -eq $size) {
        return 0
    }

    return $size.Width
}
