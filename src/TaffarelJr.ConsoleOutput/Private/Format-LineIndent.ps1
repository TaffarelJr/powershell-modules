function Format-LineIndent {
    <#
    .SYNOPSIS
        Returns the leading spaces of one output line.
    .DESCRIPTION
        Not exported. Every line writer's line sits one level's width
        (DefaultIndentWidth) in from the indent the indent stack holds, so a
        marker line never starts at the very edge.
    .OUTPUTS
        The spaces.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return ' ' * ($script:IndentWidth + (Get-AmbientIndent))
}
