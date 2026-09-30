function Install-RequiredModule {
    <#
    .SYNOPSIS
        Installs one required module for the current user.
    .PARAMETER Module
        One result from Get-RequiredModule.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Module
    )

    process {
        $parameters = Get-ModuleInstallParameter -Module $Module
        Install-Module @parameters
    }
}
