function Test-RequiredModule {
    <#
    .SYNOPSIS
        Reports whether a required module is installed
        at its minimum version or later.
    .PARAMETER Module
        One result from Get-RequiredModule.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Module
    )

    process {
        $installed = Get-Module -Name $Module.Name -ListAvailable |
        Where-Object { $_.Version -ge $Module.MinimumVersion }

        return [bool]$installed
    }
}
