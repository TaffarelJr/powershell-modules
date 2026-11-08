function Get-ModuleRequirementText {
    <#
    .SYNOPSIS
        Returns how a message names a required module: with its minimum
        version, or by name alone when any version will do.
    .PARAMETER Module
        One result from Get-RequiredModule.
    .OUTPUTS
        'Pester 5.0.0 or later' for a module with a minimum version, and
        'Pester' for one without.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Module
    )

    process {
        if ($null -eq $Module.MinimumVersion) {
            return $Module.Name
        }

        return "$($Module.Name) $($Module.MinimumVersion) or later"
    }
}
