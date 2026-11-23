using namespace System.Collections
using namespace System.Management

function Test-FieldContainer {
    <#
    .SYNOPSIS
        Tells whether a value is something Show-FieldList can list the
        elements of.
    .DESCRIPTION
        Not exported. A list, a dictionary or a custom object is a container.
        A string is not, though it can be enumerated, and neither is $null
        or any other object, such as a number, a date or a file item.
    .PARAMETER Value
        The value to test.
    .OUTPUTS
        True when the value is a container.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value -or $Value -is [string]) {
        return $false
    }

    # [PSCustomObject] is an accelerator for PSObject, which is not the type
    # of a custom object's base; Automation.PSCustomObject is.
    return $Value -is [IEnumerable] -or
        $Value.PSObject.BaseObject -is [Automation.PSCustomObject]
}
