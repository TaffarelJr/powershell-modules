function Write-Field {
    <#
    .SYNOPSIS
        Prints an aligned name/value line.
    .PARAMETER Name
        Budgeted at 15 columns;
        a longer name pushes its value out of the column.
        May be empty, which prints the value alone,
        continuing the field above.
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

        [int]$Indent = -1
    )

    process {
        Close-OpenLine
        $prefix = Get-LineIndent -Indent $Indent
        Write-Host ('{0}{1,-14} {2}' -f $prefix, "${Name}:", $Value) -ForegroundColor Gray
    }
}
