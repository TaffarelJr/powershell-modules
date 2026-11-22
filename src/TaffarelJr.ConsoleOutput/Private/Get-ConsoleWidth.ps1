function Get-ConsoleWidth {
    <#
    .SYNOPSIS
        Returns the console's width in columns, or the fallback width when
        there is no console to measure.
    .DESCRIPTION
        Not exported. The fallback width is used when standard output is
        redirected, so a log written to a file does not take the width of
        whichever window happened to run it, and when the host has no window
        or reports no width, as a runspace created with [powershell]::Create()
        does.
    .OUTPUTS
        The width in columns.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    if (-not [Console]::IsOutputRedirected) {
        $size = $Host.UI.RawUI.WindowSize
        if ($null -ne $size -and $size.Width -gt 0) {
            return $size.Width
        }
    }

    return $script:FallbackConsoleWidth
}
