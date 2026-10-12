function ConvertTo-GitHubActionsAnnotationValue {
    <#
    .SYNOPSIS
        Returns an annotation property's value in the form the command
        takes, or nothing when it holds nothing usable.
    .DESCRIPTION
        Not exported. File and Title must be text that is not blank; Line,
        EndLine, Column, and EndColumn a whole number from 1 to the largest
        Int32, of any numeric type (5, 5L, 5.0, and a BigInteger alike). A
        piped record may hold anything in a property of the same name, so
        such a value is taken as not given - text included, even text of
        digits, as a matched line may be. With -Strict, for a value given on
        the command line, whole-number text is a number too, and anything
        unusable throws.
    .PARAMETER Name
        The parameter the value is for.
    .PARAMETER Value
        The value, as it was bound.
    .PARAMETER Strict
        Throws for a value that is not usable.
    .OUTPUTS
        The text or the number, or nothing.
    #>
    [CmdletBinding()]
    [OutputType([string], [int])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('File', 'Line', 'EndLine', 'Column', 'EndColumn', 'Title')]
        [string]$Name,

        [AllowNull()]
        [object]$Value,

        [switch]$Strict
    )

    $text = [string]$Value
    if ($Name -in 'File', 'Title') {
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            return $text
        }

        if ($Strict) {
            $what = @{ File = "the file's path"; Title = 'a title' }[$Name]
            throw "-$Name is blank: give $what, or leave it out."
        }

        return
    }

    $whole = $null
    $typeName = ''
    if ($null -ne $Value) {
        $typeName = $Value.GetType().FullName
    }

    $primitive = 'System.SByte', 'System.Byte', 'System.Int16', 'System.UInt16', 'System.Int32', 'System.UInt32',
        'System.Int64', 'System.UInt64', 'System.Single', 'System.Double', 'System.Decimal'
    $wide = 'System.Numerics.BigInteger', 'System.Int128', 'System.UInt128'
    if ($typeName -in $primitive) {
        $number = [double]$Value
        if ([double]::IsFinite($number) -and [Math]::Truncate($number) -eq $number) {
            $whole = [bigint]::new($number)
        }
    }
    elseif ($typeName -in $wide) {
        $whole = [bigint]::Parse($text, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    elseif ($Strict -and $typeName -eq 'System.String') {
        $parsed = [bigint]::Zero
        $style = [System.Globalization.NumberStyles]::Integer
        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        if ([bigint]::TryParse($text, $style, $culture, [ref]$parsed)) {
            $whole = $parsed
        }
    }

    if ($null -ne $whole -and $whole -ge 1 -and $whole -le [int]::MaxValue) {
        return [int]$whole
    }

    if (-not $Strict) {
        return
    }

    if ($typeName -eq 'System.Char') {
        throw "-$Name is a character, not a number: give 5, not [char]5."
    }

    $range = "from 1 to $([int]::MaxValue)"
    if ($null -ne $whole) {
        throw "-$Name is $whole, but it must be $range`: give one in that range, or leave it out."
    }

    $shownText = Hide-UrlCredential -Text $text
    throw "-$Name is '$shownText', which is not a whole number: give one $range, or leave it out."
}
