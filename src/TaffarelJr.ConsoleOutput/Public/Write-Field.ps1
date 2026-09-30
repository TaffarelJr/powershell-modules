function Write-Field {
    <#
    .SYNOPSIS
        Prints an aligned name/value line.
    .PARAMETER Name
        May be empty, which prints the value alone,
        continuing the field above.
    .PARAMETER Budget
        Column width reserved for "Name:" before the value starts;
        a longer name pushes its value out of the column.
    .PARAMETER Indent
        Overrides the ambient indent (see Push-Indent) for this line only.
    .EXAMPLE
        Get-ChildItem Env: | Write-Field
        Binds Name/Value by property name,
        so a stream of name/value objects can be piped straight through.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [string]$Value,

        [int]$Budget = 15,
        [int]$Indent = -1
    )

    process {
        Close-OpenLine
        $prefix = Format-LineIndent -Indent $Indent
        $field = "${Name}:".PadRight($Budget - 1)
        Write-Host "$prefix$field $Value" -ForegroundColor Gray
    }
}
