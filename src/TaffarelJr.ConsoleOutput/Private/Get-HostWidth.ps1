function Get-HostWidth {
    <#
    .SYNOPSIS
        Returns the host window's width as the host reports it.
    .DESCRIPTION
        Not exported. Throws, or returns 0, when there is no real window.
        Returns 0 as well when the process's standard output is redirected:
        a log written to a file should not take the width of whatever window
        happened to run it. Redirecting a PowerShell stream inside the session
        (*> log.txt) leaves standard output on the console, so the window's
        width is kept.
        Kept apart from Get-ConsoleWidth so a test can stand in for a host
        that is wide, narrow, or absent.
    #>
    if (Test-OutputRedirected) {
        return 0
    }

    return $Host.UI.RawUI.WindowSize.Width
}
