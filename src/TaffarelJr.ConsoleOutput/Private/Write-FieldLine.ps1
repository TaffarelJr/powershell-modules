function Write-FieldLine {
    <#
    .SYNOPSIS
        Writes one aligned name/value field at the current indent.
    .DESCRIPTION
        Not exported. The body of Write-Field: ends any open "Doing" line,
        prints a name's earlier lines on their own, pads its last line to the
        budget by what shows on screen, and lines every later line of the
        value up under the first one's text.
    .PARAMETER Name
        The field's name; may be empty, which leaves the name column blank.
    .PARAMETER Value
        The value, formatted by Format-FieldValue.
    .PARAMETER Budget
        Columns from the indent to where the value starts, the separating
        space included.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [object]$Value,

        [Parameter(Mandatory)]
        [int]$Budget
    )

    Close-OpenLine
    $prefix = Format-LineIndent
    $nameLines = @(Split-TextLine -Text $Name)
    for ($i = 0; $i -lt $nameLines.Count - 1; $i++) {
        Write-MessageLine -Lead $prefix -Continuation '' -Text $nameLines[$i] -Color Gray
    }

    $last = $nameLines[-1]
    $label = if ($last) { "${last}:" } else { '' }
    $labelWidth = Get-VisibleLength -Text $label
    $padding = [Math]::Max(0, $Budget - 1 - $labelWidth)
    $lead = "$prefix$label$(' ' * $padding) "
    $continuation = ' ' * ($prefix.Length + $labelWidth + $padding + 1)
    $text = Format-FieldValue -Value $Value
    Write-MessageLine -Lead $lead -Continuation $continuation -Text $text -Color Gray
}
