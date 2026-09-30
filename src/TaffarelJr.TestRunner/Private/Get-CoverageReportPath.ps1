using namespace System.IO

function Get-CoverageReportPath {
    <#
    .SYNOPSIS
        Returns where a test file's coverage report goes:
        its display name under the output folder, as Cobertura XML.
    #>
    param(
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$Name
    )

    $relative = $Name -replace '/', [Path]::DirectorySeparatorChar
    return Join-Path $OutputPath "$relative.cobertura.xml"
}
