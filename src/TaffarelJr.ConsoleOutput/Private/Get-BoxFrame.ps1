New-Variable -Name BoxBottomLeft -Value "`u{2514}" -Option Constant -Scope Script
New-Variable -Name BoxBottomRight -Value "`u{2518}" -Option Constant -Scope Script
New-Variable -Name BoxHorizontal -Value "`u{2500}" -Option Constant -Scope Script
New-Variable -Name BoxTopLeft -Value "`u{250C}" -Option Constant -Scope Script
New-Variable -Name BoxTopRight -Value "`u{2510}" -Option Constant -Scope Script
New-Variable -Name BoxVertical -Value "`u{2502}" -Option Constant -Scope Script

function Get-BoxFrame {
    <#
    .SYNOPSIS
        Returns the strings that surround a box's text: the line above it, the
        line below it, and what leads and trails each line of it.
    .DESCRIPTION
        Not exported. The one place the box-drawing characters are used. A
        frame is either two rules, which lead and trail nothing, or a full
        box, whose lead and trail are the side character and a space.
    .PARAMETER Indent
        The spaces that start every line of the frame.
    .PARAMETER ContentWidth
        How many columns of text the frame encloses.
    .PARAMETER Bordered
        A full box rather than two rules.
    .OUTPUTS
        An object with Top, Bottom, Lead and Trail.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Indent,

        [Parameter(Mandatory)]
        [int]$ContentWidth,

        [switch]$Bordered
    )

    if ($Bordered) {
        $edge = $script:BoxHorizontal * ($ContentWidth + 2)
        return [PSCustomObject]@{
            Top    = "$Indent$script:BoxTopLeft$edge$script:BoxTopRight"
            Bottom = "$Indent$script:BoxBottomLeft$edge$script:BoxBottomRight"
            Lead   = "$Indent$script:BoxVertical "
            Trail  = " $script:BoxVertical"
        }
    }

    $rule = "$Indent$($script:BoxHorizontal * $ContentWidth)"
    return [PSCustomObject]@{
        Top    = $rule
        Bottom = $rule
        Lead   = $Indent
        Trail  = ''
    }
}
