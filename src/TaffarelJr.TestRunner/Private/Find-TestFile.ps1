function Find-TestFile {
    <#
    .SYNOPSIS
        Returns every *.Tests.ps1 under one or more folders whose name
        matches the filter, sorted by path, always as an array.
    #>
    param(
        [Parameter(Mandatory)][string[]]$Path,
        [string]$Filter = '*'
    )

    $files = Get-ChildItem -LiteralPath $Path -Recurse -File -Filter "$Filter.Tests.ps1"
    return , @($files | Sort-Object FullName)
}
