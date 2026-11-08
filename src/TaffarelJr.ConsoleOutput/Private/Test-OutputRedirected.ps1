function Test-OutputRedirected {
    <#
    .SYNOPSIS
        Returns whether standard output goes to a file or a pipe
        rather than to a console.
    .DESCRIPTION
        Not exported. Kept apart from Get-HostWidth so a test can choose
        the answer.
    .OUTPUTS
        True when standard output is redirected.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [Console]::IsOutputRedirected
}
