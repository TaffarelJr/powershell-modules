function Get-RequiredModule {
    <#
    .SYNOPSIS
        Reads a RequiredModules.psd1-style manifest,
        returning one object per required module.
    .DESCRIPTION
        -Path is read with Import-PowerShellDataFile, not dot-sourced -
        a manifest is data, and parsing it as data means
        it can never run arbitrary code.
        Either way, every entry is validated before use,
        so a malformed manifest fails with a clear message here
        instead of a confusing error somewhere else.
    .PARAMETER Path
        The path to a .psd1 file: a hashtable keyed by module name,
        each value a hashtable with MinimumVersion
        and, optionally, DocumentationUrl.
    .PARAMETER Data
        The manifest itself, in the same shape -
        for a caller that builds it in code instead of
        maintaining a separate .psd1 file. Accepts pipeline input.
    #>
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'ByData', ValueFromPipeline)]
        [hashtable]$Data
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "RequiredModules manifest not found: $Path"
        }

        $Data = Import-PowerShellDataFile -LiteralPath $Path
    }

    $modules = foreach ($name in $Data.Keys) {
        Get-RequiredModuleEntry -Name $name -Entry $Data[$name]
    }

    return , @($modules)
}
