function Format-LineIndent {
    <#
    .SYNOPSIS
        Returns the leading-space prefix for one output line.
    .DESCRIPTION
        Every marker line sits two spaces in from the ambient indent,
        so a Write-Success at indent 0 lines up the same way it always has.
    .PARAMETER Indent
        -1 (the default) means "use the ambient indent from Push-Indent".
        Any other value overrides the ambient indent for this one call only -
        it does not touch the Push-Indent stack.
    #>
    param(
        [int]$Indent = -1
    )

    $ambient = if ($Indent -ge 0) {
        $Indent
    }
    else {
        Get-Indent
    }

    return ' ' * ($script:DefaultIndentWidth + $ambient)
}
