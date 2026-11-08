function Get-ConsoleWidth {
    <#
    .SYNOPSIS
        Returns the terminal's current width,
        or a fixed default when there isn't a real one to measure.
    .DESCRIPTION
        Not exported. Most CI log viewers (GitHub Actions included) attach no
        real terminal, and a process whose standard output goes to a file or a
        pipe is treated the same way: Get-HostWidth reports 0 for both.
        80 matches this project's own line-width convention,
        so a banner in a log reads at the same width as everything else in it.
    .OUTPUTS
        The width in columns.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    $width = Get-HostWidth
    if ($width -gt 0) {
        return $width
    }

    return 80
}
