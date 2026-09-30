using namespace System.Collections

function Get-RequiredModuleEntry {
    <#
    .SYNOPSIS
        Validates and converts one manifest entry,
        throwing a clear error when its shape is wrong.
    .PARAMETER Name
        The module name this entry is keyed by -
        named in any error,
        since a malformed manifest is otherwise hard to place.
        The shape of a Gallery package name: letters, digits and '_',
        joined by single '.' or '-' characters. A wildcard or a path would
        match modules other than the one meant, and a leading '-' would turn
        the install command shown for it into a parameter.
    .PARAMETER Entry
        The value for that name:
        a hashtable with, optionally, MinimumVersion and DocumentationUrl.
        Any other key is refused, since a misspelled one
        (a RequiredVersion, say) would otherwise be ignored without a word.
        MinimumVersion is a string or a [Version]; left out, any version of
        the module will do, and the object has none. An unquoted number is
        refused: it has already lost its trailing zeros, so 5.10 would be 5.1.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        $Entry
    )

    if ($Name -notmatch '^\w+(?:[.-]\w+)*\z') {
        throw "RequiredModules entry '$Name' is not a valid module name: " +
        "use letters, digits and '_', joined by single '.' or '-' characters."
    }

    if ($Entry -isnot [IDictionary]) {
        $actualType = if ($null -eq $Entry) {
            '$null'
        }
        else {
            $Entry.GetType().Name
        }

        throw "RequiredModules entry '$Name' must be a hashtable, not $actualType."
    }

    # PSBase: a key named Keys would otherwise be read in place of every key,
    # and its value checked as if it were the key.
    foreach ($key in $Entry.PSBase.Keys) {
        if ($key -notin 'MinimumVersion', 'DocumentationUrl') {
            throw "RequiredModules entry '$Name' has an unknown key '$key' " +
            "(allowed: MinimumVersion, DocumentationUrl)."
        }
    }

    $minimumVersion = $null
    if ($Entry.Contains('MinimumVersion')) {
        $written = $Entry['MinimumVersion']
        if ($written -is [Version]) {
            $written = $written.ToString()
        }

        if ($null -ne $written -and $written -isnot [string]) {
            throw "RequiredModules entry '$Name' has a MinimumVersion that is a $($written.GetType().Name), " +
            "not a quoted version such as '5.0.0'."
        }

        if (-not [Version]::TryParse($written, [ref]$minimumVersion)) {
            throw "RequiredModules entry '$Name' has an invalid MinimumVersion '$written' " +
            "(use a quoted version such as '5.0.0')."
        }
    }

    $documentationUrl = $Entry['DocumentationUrl']
    if ($null -ne $documentationUrl -and $documentationUrl -isnot [string]) {
        throw "RequiredModules entry '$Name' has a DocumentationUrl that is not a string."
    }

    return [PSCustomObject]@{
        Name             = $Name
        MinimumVersion   = $minimumVersion
        DocumentationUrl = $documentationUrl
    }
}
