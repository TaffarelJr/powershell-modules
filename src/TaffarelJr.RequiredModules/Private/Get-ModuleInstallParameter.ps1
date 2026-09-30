function Get-ModuleInstallParameter {
    <#
    .SYNOPSIS
        Returns the splat hashtable for installing one required module.
    .PARAMETER Module
        One result from Get-RequiredModule.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Module
    )

    process {
        return @{
            Name               = $Module.Name
            MinimumVersion     = $Module.MinimumVersion
            Scope              = 'CurrentUser'
            Force              = $true
            SkipPublisherCheck = $true
        }
    }
}
