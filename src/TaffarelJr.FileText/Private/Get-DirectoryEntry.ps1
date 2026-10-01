function Get-DirectoryEntry {
    <#
    .SYNOPSIS
        Lists what is directly inside one folder, hidden items included.
    .DESCRIPTION
        Not exported. A function of its own so a test can make one folder
        unreadable without depending on file permissions. Throws when the
        folder cannot be listed.
    .PARAMETER Path
        The folder.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop
}
