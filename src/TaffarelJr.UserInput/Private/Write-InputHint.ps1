function Write-InputHint {
    <#
    .SYNOPSIS
        Prints the context lines shown immediately before a prompt.
    .DESCRIPTION
        Not exported - shared by Read-Input and Read-Secret
        so the two can't drift apart on how a hint is rendered.
    #>
    param(
        [string[]]$Hint
    )

    foreach ($line in $Hint) {
        Write-Detail $line
    }
}
