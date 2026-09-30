function Get-BaseValue {
    <#
    .SYNOPSIS
        Returns a value without the PSObject wrapper a cmdlet's output
        carries.
    .DESCRIPTION
        Not exported. The result of Test-Path, ForEach, or Select-Object
        arrives wrapped, and a wrapped bool or number still answers "yes" to
        -is [pscustomobject], so comparing or rendering it as the object it
        is not gives the wrong answer. A genuine PSCustomObject is left as
        it is.
    .PARAMETER Value
        The value to unwrap.
    .OUTPUTS
        The value itself, as one object even when it is an array. This
        returns a value, not a list of results, so the leading comma stops
        the array being written out one element at a time.
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Value
    )

    if ($Value -is [psobject]) {
        $base = $Value.psobject.BaseObject
        if ($base -isnot [System.Management.Automation.PSCustomObject]) {
            return , $base
        }
    }

    return , $Value
}
