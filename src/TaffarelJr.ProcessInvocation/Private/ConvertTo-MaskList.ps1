function ConvertTo-MaskList {
    <#
    .SYNOPSIS
        Returns the values a caller gave as -Mask as plain strings, and
        refuses a SecureString.
    .DESCRIPTION
        Not exported. A SecureString converts to its type name, so taken as a
        string it would hide those words and leave the secret in view: -Mask
        takes the secret as plain text. A $null entry becomes an empty one,
        which hiding ignores.
    .PARAMETER Mask
        The values as the caller gave them.
    .OUTPUTS
        The values as strings, one at a time; nothing for $null or an empty
        list.
    #>
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Mask
    )

    foreach ($value in $Mask) {
        if ($value -is [securestring]) {
            throw '-Mask takes plain text: a SecureString would hide only its type name. ' +
            'Pass the secret as a string.'
        }

        "$value"
    }
}
