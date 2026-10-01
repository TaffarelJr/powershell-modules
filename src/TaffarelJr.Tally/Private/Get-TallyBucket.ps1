function Get-TallyBucket {
    <#
    .SYNOPSIS
        Returns the ordered counter bucket a -Key resolves to,
        creating it empty first if this is the key's first use.
    .DESCRIPTION
        $null or an empty string resolves to the shared, global bucket -
        every public function in this module treats an omitted -Key
        the same way, so that case is handled here, once.
    .PARAMETER Key
        The namespace to isolate. $null or empty for the global bucket.
    #>
    param(
        [string]$Key
    )

    if ([string]::IsNullOrEmpty($Key)) {
        return $script:Tallies
    }

    if (-not $script:KeyedTallies.Contains($Key)) {
        $script:KeyedTallies[$Key] = [ordered]@{}
    }

    return $script:KeyedTallies[$Key]
}
