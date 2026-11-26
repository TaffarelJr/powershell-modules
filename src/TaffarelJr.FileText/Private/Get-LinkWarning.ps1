function Get-LinkWarning {
    <#
    .SYNOPSIS
        Names each link whose target path holds the token.
    .DESCRIPTION
        Not exported. Nothing in a token pass rewrites a link's target, and
        renaming what a link points at leaves the link dangling, so a link
        whose target says the token is named for the caller to re-point by
        hand. Only symbolic links and junctions are links here. A hard link is
        an ordinary file with a second name.
    .PARAMETER Item
        The candidates, as Get-TokenCandidate returns them.
    .PARAMETER From
        The token to look for in each target.
    .OUTPUTS
        One "Link target still says ..." line for each such link.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Item,

        [Parameter(Mandatory)]
        [string]$From
    )

    $links = @($Item | Where-Object { $_.LinkType -in 'Junction', 'SymbolicLink' })
    foreach ($link in $links) {
        if ($link.LinkTarget -and $link.LinkTarget.Contains($From)) {
            "Link target still says '$From': $($link.FullName) -> $($link.LinkTarget)"
        }
    }
}
