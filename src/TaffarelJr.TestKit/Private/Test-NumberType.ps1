function Test-NumberType {
    <#
    .SYNOPSIS
        Reports whether a value is a number that compares by value with
        numbers of other types.
    .DESCRIPTION
        Not exported. The primitive integer and floating-point types and
        decimal are numbers. A boolean, a char and a pointer ([IntPtr],
        [UIntPtr]) are primitives too, but not numbers here, and neither are
        BigInteger, Int128, UInt128 or Half: they all compare by type and
        Equals.
    .PARAMETER Value
        The value to check, already unwrapped from any PSObject.
    #>
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    $type = $Value.GetType()
    if ($type -eq [decimal]) {
        return $true
    }

    return $type.IsPrimitive -and $type -notin [bool], [char], [IntPtr], [UIntPtr]
}
