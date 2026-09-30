function Test-MinimumVersion {
    <#
    .SYNOPSIS
        Reports whether an installed version meets a minimum version.
    .DESCRIPTION
        Compares the two as .NET [Version] values, as Import-Module
        -MinimumVersion does, so a missing part counts as lower than a zero:
        5.0 does not meet 5.0.0.
    .PARAMETER InstalledVersion
        The highest version found, from Get-InstalledModuleVersion,
        or $null when there is none.
    .PARAMETER MinimumVersion
        The version required, or $null when any version will do.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [Version]$InstalledVersion,

        [Parameter(Mandatory)]
        [AllowNull()]
        [Version]$MinimumVersion
    )

    if ($null -eq $InstalledVersion) {
        return $false
    }

    return $null -eq $MinimumVersion -or $InstalledVersion -ge $MinimumVersion
}
