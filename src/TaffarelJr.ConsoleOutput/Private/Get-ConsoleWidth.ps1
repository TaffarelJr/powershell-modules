function Get-ConsoleWidth {
    <#
    .SYNOPSIS
        Returns the terminal's current width,
        or a fixed default when there isn't a real one to measure.
    .DESCRIPTION
        Most CI log viewers (GitHub Actions included) attach no real terminal,
        so RawUI.WindowSize either throws or returns 0.
        80 matches this project's own line-width convention,
        so a banner in a CI log reads at the same width as everything else in it.
    #>
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -gt 0) {
            return $width
        }
    }
    catch {
        # No real terminal - fall through to the default below.
    }

    return 80
}
