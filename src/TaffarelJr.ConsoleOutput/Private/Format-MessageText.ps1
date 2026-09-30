function Format-MessageText {
    <#
    .SYNOPSIS
        Returns text safe to print, substituting a placeholder for blank input.
    .DESCRIPTION
        A message built from interpolation can come out empty,
        and a logging call must never be the thing
        that makes a line silently vanish.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return '(no message)'
    }

    return $Text
}
