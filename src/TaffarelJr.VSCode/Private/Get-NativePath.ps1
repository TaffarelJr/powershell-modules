function Get-NativePath {
    <#
    .SYNOPSIS
        Resolves an existing path to the filesystem path .NET and git will
        see.
    .DESCRIPTION
        Not exported. Resolve-Path's .Path is the PowerShell path, which
        under a mapped PSDrive reads 'Work:\MyRepo' - a prefix that shares
        nothing with a FileInfo's FullName, so comparing the two silently
        produces nonsense. .ProviderPath is the real one.
    .PARAMETER Path
        The path to resolve. It has to exist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return (Resolve-Path -LiteralPath $Path).ProviderPath
}
