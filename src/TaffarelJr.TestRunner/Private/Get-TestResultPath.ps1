using namespace System.IO

function Get-TestResultPath {
    <#
    .SYNOPSIS
        Returns where a test file's JUnit result report goes:
        its display name under the output folder, as JUnit XML.
    .PARAMETER OutputPath
        The folder the reports go under.
    .PARAMETER Name
        The file's display name, from Get-TestDisplayName.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $relative = $Name -replace '/', [Path]::DirectorySeparatorChar
    return Join-Path $OutputPath "$relative.junit.xml"
}
