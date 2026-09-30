function Get-RequiredModuleEntry {
    <#
    .SYNOPSIS
        Validates and converts one manifest entry,
        throwing a clear error when its shape is wrong.
    .PARAMETER Name
        The module name this entry is keyed by -
        named in any error,
        since a malformed manifest is otherwise hard to place.
    .PARAMETER Entry
        The value for that name:
        a hashtable with MinimumVersion and, optionally, DocumentationUrl.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        $Entry
    )

    if ($Entry -isnot [hashtable]) {
        $actualType = if ($null -eq $Entry) {
            '$null'
        }
        else {
            $Entry.GetType().Name
        }

        throw "RequiredModules entry '$Name' must be a hashtable, not $actualType."
    }

    if (-not $Entry.ContainsKey('MinimumVersion')) {
        throw "RequiredModules entry '$Name' is missing MinimumVersion."
    }

    $minimumVersion = try {
        [Version]$Entry.MinimumVersion
    }
    catch {
        throw "RequiredModules entry '$Name' has an invalid MinimumVersion '$($Entry.MinimumVersion)'."
    }

    # StrictMode throws on a hashtable key that isn't present at all,
    # not just one that's empty - DocumentationUrl is optional,
    # so it has to be checked for, not assumed.
    $documentationUrl = if ($Entry.ContainsKey('DocumentationUrl')) {
        $Entry.DocumentationUrl
    }
    else {
        $null
    }

    return [PSCustomObject]@{
        Name             = $Name
        MinimumVersion   = $minimumVersion
        DocumentationUrl = $documentationUrl
    }
}
