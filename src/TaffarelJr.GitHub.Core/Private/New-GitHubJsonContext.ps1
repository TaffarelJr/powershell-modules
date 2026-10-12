function New-GitHubJsonContext {
    <#
    .SYNOPSIS
        Returns the settings and caches one conversion of a JSON value
        shares across every object it builds.
    .DESCRIPTION
        Not exported. Property names repeat across the elements of a list,
        so each is re-cased once and looked up after that. The caches are
        per conversion, so names that are data - file names, say - never
        pile up between calls.
    .PARAMETER KeepFieldNames
        Leaves property names as they are instead of re-casing them.
    .PARAMETER KeepKeysOf
        Names of properties whose value is keyed by data.
    .OUTPUTS
        A hashtable: KeepFieldNames, KeepKeysOf, Names, DateKeys, Reserved,
        and Iso.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseLiteralInitializerForHashtable',
        '',
        Justification = 'Case-sensitive on purpose: JSON keys that differ only in case must stay distinct.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Builds the caches of one conversion in memory; nothing outside the process changes.')]
    param(
        [bool]$KeepFieldNames,

        [AllowNull()]
        [string[]]$KeepKeysOf
    )

    $kept = [hashtable]::new([StringComparer]::Ordinal)
    foreach ($name in $KeepKeysOf) {
        $kept[$name] = $true
    }

    # Names a PSCustomObject cannot hold: an object with one of these keys
    # comes back as a dictionary instead.
    $reserved = [hashtable]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in '', 'PSObject', 'PSBase', 'PSAdapted', 'PSExtended', 'PSTypeNames') {
        $reserved[$name] = $true
    }

    $date = '[0-9]{4}-[0-9]{2}-[0-9]{2}'
    $time = '[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?'
    $zone = '(?:Z|[+-][0-9]{2}:[0-9]{2})'

    return @{
        KeepFieldNames = $KeepFieldNames
        KeepKeysOf     = $kept
        Names          = [hashtable]::new([StringComparer]::Ordinal)
        DateKeys       = [hashtable]::new([StringComparer]::Ordinal)
        Reserved       = $reserved
        Iso            = [regex]"^${date}T$time$zone$"
    }
}
