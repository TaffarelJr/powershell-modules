function Get-AmbientIndent {
    <#
    .SYNOPSIS
        Returns the indent the indent stack holds, in spaces.
    .DESCRIPTION
        Not exported. One of the helpers that own the indent stack: the sum of
        every width Push-Indent or Invoke-Indented pushed and not yet taken
        off; zero when nothing is pushed. Get-Indent returns it to callers,
        and the writers read it here, so no public function calls another.
    .OUTPUTS
        The indent, in spaces.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    $total = 0
    foreach ($width in $script:IndentStack) {
        $total += $width
    }

    return $total
}
