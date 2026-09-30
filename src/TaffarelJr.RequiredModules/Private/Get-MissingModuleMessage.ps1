function Get-MissingModuleMessage {
    <#
    .SYNOPSIS
        Builds the text explaining a missing module and how to fix it.
    .PARAMETER Module
        One result from Get-RequiredModule.
    .PARAMETER InstalledVersion
        The highest version found, from Get-InstalledModuleVersion, when an
        older one is installed - so the message does not call a module
        that is there "not installed". Omit it when there is none.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Module,

        [AllowNull()]
        [Version]$InstalledVersion
    )

    process {
        $need = "$(Get-ModuleRequirementText -Module $Module) is required"
        $problem = if ($InstalledVersion) {
            "$need, but only $InstalledVersion is installed."
        }
        else {
            "$need but not installed."
        }

        $lines = @(
            $problem
            "Install it with: $(Get-ModuleInstallCommand -Module $Module)"
        )
        if ($Module.DocumentationUrl) {
            $lines += "Docs: $($Module.DocumentationUrl)"
        }

        return $lines -join "`n"
    }
}
