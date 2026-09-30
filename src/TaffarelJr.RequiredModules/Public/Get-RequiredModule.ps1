function Get-RequiredModule {
    <#
    .SYNOPSIS
        Reads a RequiredModules.psd1-style manifest,
        returning one object per required module.
    .DESCRIPTION
        Read with Import-PowerShellDataFile, not dot-sourced -
        a manifest is data, and parsing it as data means
        it can never run arbitrary code.
    .PARAMETER Path
        The manifest file: a hashtable keyed by module name,
        each value a hashtable with MinimumVersion
        and, optionally, DocumentationUrl.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $manifest = Import-PowerShellDataFile -LiteralPath $Path
    $modules = foreach ($name in $manifest.Keys) {
        $entry = $manifest[$name]
        # StrictMode throws on a hashtable key that isn't present at all,
        # not just one that's empty - DocumentationUrl is optional,
        # so it has to be checked for, not assumed.
        $documentationUrl = if ($entry.ContainsKey('DocumentationUrl')) { $entry.DocumentationUrl } else { $null }

        [pscustomobject]@{
            Name             = $name
            MinimumVersion   = [version]$entry.MinimumVersion
            DocumentationUrl = $documentationUrl
        }
    }

    return , @($modules)
}
