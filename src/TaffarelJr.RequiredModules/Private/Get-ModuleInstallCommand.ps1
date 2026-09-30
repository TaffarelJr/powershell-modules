function Get-ModuleInstallCommand {
    <#
    .SYNOPSIS
        Renders the Install-Module command line for one required module,
        for display in an error or prompt message.
    .PARAMETER Module
        One result from Get-RequiredModule.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Module
    )

    process {
        return "Install-Module -Name $($Module.Name) -MinimumVersion $($Module.MinimumVersion) -Scope CurrentUser"
    }
}
