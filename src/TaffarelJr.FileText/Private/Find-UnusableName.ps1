function Find-UnusableName {
    <#
    .SYNOPSIS
        Lists the items whose new name, once the token is replaced, would be
        unusable on Windows.
    .DESCRIPTION
        Not exported. Run before anything is changed, so an unusable name
        cannot leave a tree whose contents are renamed and whose paths are
        not. Older Windows and many Windows tools treat a name whose part
        before the first dot is a device name as that device, whatever its
        case or extension: CON, PRN, AUX, NUL, COM0 to COM9, LPT0 to LPT9,
        and COM or LPT with a superscript digit. And Windows quietly drops a
        trailing dot or space, so the name on disk would not be the name asked
        for.
    .PARAMETER Item
        The candidates, as Get-TokenCandidate returns them.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with.
    .OUTPUTS
        One "<path> -> <new name> - <reason>" line for each unusable name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Item,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [string]$To
    )

    $device = '^(CON|PRN|AUX|NUL|COM[0-9\u00B9\u00B2\u00B3]|LPT[0-9\u00B9\u00B2\u00B3])$'
    foreach ($entry in $Item) {
        if (-not $entry.Name.Contains($From)) {
            continue
        }

        $newName = $entry.Name.Replace($From, $To)
        $stem = $newName.Split('.')[0].TrimEnd(' ')
        $prefix = "$($entry.FullName) -> $newName -"
        if ($stem -match $device) {
            "$prefix older Windows and many Windows tools treat it as a device."
        }
        elseif ($newName.EndsWith('.', 'Ordinal') -or $newName.EndsWith(' ', 'Ordinal')) {
            "$prefix Windows drops a trailing dot or space," +
            ' so the name on disk would not be the one asked for.'
        }
    }
}
