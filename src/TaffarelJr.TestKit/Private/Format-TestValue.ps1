function Format-TestValue {
    <#
    .SYNOPSIS
        Renders a value for a failure message, cut to a readable length
        around where it differs from the other value.
    .DESCRIPTION
        Not exported. The text is Get-TestValueText's. A rendering longer
        than 240 characters is cut, and each cut is marked with "...". The
        part shown is the start, unless the value is given the other value
        it was compared with and the two differ further in; then it is the
        part around the first difference, so two long values that differ
        late still print apart.
    .PARAMETER Value
        The value to render.
    .PARAMETER Other
        The value it was compared with, to find where the two differ and to
        tell apart two numbers that print alike (see Get-TestValueText).
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Value,

        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Other
    )

    $limit = 240
    $before = 40
    $hasOther = $PSBoundParameters.ContainsKey('Other')
    $text = Get-TestValueText -Value $Value -Other $Other
    if ($text.Length -le $limit) {
        return $text
    }

    $start = 0
    if ($hasOther) {
        $otherText = Get-TestValueText -Value $Other -Other $Value
        $shorter = [Math]::Min($text.Length, $otherText.Length)
        $difference = 0
        while ($difference -lt $shorter -and $text[$difference] -ceq $otherText[$difference]) {
            $difference++
        }

        if ($difference -ge $limit - $before) {
            $start = [Math]::Min($difference - $before, $text.Length - $limit)
        }
    }

    $window = $text.Substring($start, $limit)
    if ($start -gt 0) {
        $window = "...$window"
    }

    if ($start + $limit -lt $text.Length) {
        $window = "$window..."
    }

    return $window
}
