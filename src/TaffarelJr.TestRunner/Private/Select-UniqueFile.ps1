using namespace System.Collections.Generic

function Select-UniqueFile {
    <#
    .SYNOPSIS
        Returns each file once, sorted by path, one at a time.
    .DESCRIPTION
        Two paths are the same file only when they are the same text: a
        case-sensitive file system can hold Foo.Tests.ps1 and foo.Tests.ps1
        side by side, and comparing without regard to case would drop one.
    .PARAMETER File
        Files, or any objects with a FullName, as Get-ChildItem returns them.
    .OUTPUTS
        The files, each once, in order of path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$File
    )

    $seen = [HashSet[string]]::new([StringComparer]::Ordinal)
    $unique = foreach ($item in $File) {
        if ($seen.Add($item.FullName)) {
            $item
        }
    }

    return $unique | Sort-Object -Property FullName
}
