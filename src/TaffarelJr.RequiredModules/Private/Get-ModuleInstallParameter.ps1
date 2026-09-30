function Get-ModuleInstallParameter {
    <#
    .SYNOPSIS
        Returns the splat for installing one required module.
    .DESCRIPTION
        Every switch in it is set, so Get-ModuleInstallCommand renders each
        one as a bare switch. A module with no minimum version has no
        MinimumVersion in it, so the newest version is installed.
    .PARAMETER Module
        One result from Get-RequiredModule.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Module
    )

    process {
        # SkipPublisherCheck: a new version signed by a different publisher than
        # an installed one is refused otherwise - Pester 5 over the Pester 3 that
        # ships with Windows is the usual case.
        $parameters = [ordered]@{ Name = $Module.Name }
        if ($null -ne $Module.MinimumVersion) {
            $parameters.MinimumVersion = $Module.MinimumVersion
        }

        $parameters.Scope = 'CurrentUser'
        $parameters.Force = $true
        $parameters.SkipPublisherCheck = $true
        return $parameters
    }
}
