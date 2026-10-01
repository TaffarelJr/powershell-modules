function Get-TallyBucket {
    <#
    .SYNOPSIS
        Returns the counters a -Key resolves to, or $null when that key has
        none yet.
    .DESCRIPTION
        Not exported. $null or an empty string resolves to the shared, global
        counters, which always exist - that is what an omitted -Key arrives
        as in every public function, so that case is handled here, once
        (each public function refuses a blank -Key it was actually given).
        A key's counters are created only when asked for, so reading under a
        key that was never used does not leave an empty set behind.
        The caller holds the state lock.
    .PARAMETER Key
        The namespace to isolate. $null or empty for the global counters.
    .PARAMETER Create
        Creates the key's counters when it has none, instead of returning
        $null.
    .OUTPUTS
        An ordered dictionary from name to an object with Name and Count, or
        $null.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [string]$Key,

        [switch]$Create
    )

    $state = Get-TallyState
    if ([string]::IsNullOrEmpty($Key)) {
        return $state.Global
    }

    if ($state.Keyed.Contains($Key)) {
        return $state.Keyed[$Key]
    }

    if (-not $Create) {
        return
    }

    $bucket = [ordered]@{}
    $state.Keyed[$Key] = $bucket
    return $bucket
}
