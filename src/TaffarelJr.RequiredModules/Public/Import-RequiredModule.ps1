function Import-RequiredModule {
    <#
    .SYNOPSIS
        Imports a required module at its minimum version or later.
    .PARAMETER Module
        One result from Get-RequiredModule.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Module
    )

    process {
        Import-Module -Name $Module.Name -MinimumVersion $Module.MinimumVersion -Global -Force
    }
}
