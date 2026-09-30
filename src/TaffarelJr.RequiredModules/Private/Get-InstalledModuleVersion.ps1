function Get-InstalledModuleVersion {
    <#
    .SYNOPSIS
        Returns the highest version of a module this session can use,
        or nothing when there is none.
    .DESCRIPTION
        Looks at the modules on disk (PSModulePath) and at the ones already
        loaded. A module imported by its path is usable in this session
        without being on PSModulePath at all, and Import-RequiredModule
        leaves it loaded rather than looking for it again.

        Scanning PSModulePath takes seconds on a machine with many modules,
        so a caller that only needs to know whether a minimum is met passes
        it: a loaded version that meets it is returned without the scan.
    .PARAMETER Name
        The exact module name. Wildcard characters in it are taken literally.
    .PARAMETER MinimumVersion
        The version the caller needs. When a loaded version meets it, that
        version is returned and PSModulePath is not scanned; the version
        returned may then be lower than one installed on disk. Without it,
        the highest version there is is returned.
    #>
    [CmdletBinding()]
    [OutputType([Version])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Version]$MinimumVersion
    )

    $literal = [WildcardPattern]::Escape($Name)
    $loaded = @(Get-Module -Name $literal)
    if ($null -ne $MinimumVersion) {
        $enough = @($loaded | Where-Object { $_.Version -ge $MinimumVersion })
        if ($enough.Count -gt 0) {
            return ($enough | Sort-Object -Property Version -Descending | Select-Object -First 1).Version
        }
    }

    $modules = @(Get-Module -Name $literal -ListAvailable) + $loaded
    if (-not $modules) {
        return
    }

    $highest = $modules | Sort-Object -Property Version -Descending | Select-Object -First 1
    return $highest.Version
}
