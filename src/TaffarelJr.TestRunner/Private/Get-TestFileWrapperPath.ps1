function Get-TestFileWrapperPath {
    <#
    .SYNOPSIS
        Returns the path of this module's own Scripts/Invoke-TestFile.ps1.
    .DESCRIPTION
        Not exported. Resolved from the module's base folder rather than from
        $PSScriptRoot, which names the function's own file in the source
        layout but the module root once the module is built into one file.
    .OUTPUTS
        System.String. The wrapper's full path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $base = $ExecutionContext.SessionState.Module.ModuleBase
    return Join-Path -Path $base -ChildPath 'Scripts' -AdditionalChildPath 'Invoke-TestFile.ps1'
}
