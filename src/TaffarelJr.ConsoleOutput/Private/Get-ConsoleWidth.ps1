function Get-ConsoleWidth {
    <#
    .SYNOPSIS
        Returns the terminal's current width,
        or a fixed default when there isn't a real one to measure.
    .DESCRIPTION
        Most CI log viewers (GitHub Actions included) attach no real terminal,
        so the host's window size either throws or returns 0,
        and a process whose standard output goes to a file or a pipe
        is treated the same way.
        80 matches this project's own line-width convention,
        so a banner in a log reads at the same width as everything else in it.
    #>
    $width = try {
        Get-HostWidth
    }
    catch {
        0
    }

    if ($width -gt 0) {
        return $width
    }

    return 80
}
