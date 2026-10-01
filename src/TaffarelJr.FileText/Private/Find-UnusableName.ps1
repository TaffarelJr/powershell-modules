function Find-UnusableName {
    <#
    .SYNOPSIS
        Lists the items whose new name, once the token is replaced, would be
        unusable on Windows.
    .DESCRIPTION
        Not exported. Rename-Token runs this before it changes anything, so an
        unusable name cannot leave a tree whose contents are renamed and whose
        paths are not. Older Windows and many Windows tools treat a name whose
        part before the first dot is a device name - CON, PRN, AUX, NUL,
        COM0-9, LPT0-9, and COM or LPT with a superscript digit - as that
        device, whatever its case or extension. And Windows quietly drops a
        trailing dot or space, so the name on disk would differ from the one
        in the content.
    .PARAMETER Item
        The candidates, as Get-TokenCandidate returns them.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with.
    .OUTPUTS
        One "<path> -> <new name> - <reason>" line per unusable name, one at a
        time.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Item,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$To
    )

    foreach ($entry in $Item) {
        if (-not $entry.Name.Contains($From)) {
            continue
        }

        $newName = $entry.Name.Replace($From, $To)
        $stem = $newName.Split('.')[0].TrimEnd(' ')
        if ($stem -match '^(CON|PRN|AUX|NUL|COM[0-9\u00B9\u00B2\u00B3]|LPT[0-9\u00B9\u00B2\u00B3])$') {
            "$($entry.FullName) -> $newName - older Windows and many Windows tools treat it as a device."
        }
        elseif ($newName.EndsWith('.', 'Ordinal') -or $newName.EndsWith(' ', 'Ordinal')) {
            "$($entry.FullName) -> $newName - Windows drops a trailing dot or space, " +
            'so the name on disk would not be the one asked for.'
        }
    }
}
