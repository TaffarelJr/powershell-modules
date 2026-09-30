function Get-MissingModuleMessage {
    <#
    .SYNOPSIS
        Builds the text explaining a missing module and how to fix it.
    .PARAMETER Module
        One result from Get-RequiredModule.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Module
    )

    process {
        $lines = @(
            "$($Module.Name) $($Module.MinimumVersion) or later is required but not installed."
            "Install it with: $(Get-ModuleInstallCommand -Module $Module)"
        )
        if ($Module.DocumentationUrl) {
            $lines += "Docs: $($Module.DocumentationUrl)"
        }

        return $lines -join "`n"
    }
}
