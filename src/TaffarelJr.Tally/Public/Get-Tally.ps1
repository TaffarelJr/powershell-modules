using namespace System.Threading

function Get-Tally {
    <#
    .SYNOPSIS
        Returns the sum of the adds that carry every tag you give.
    .DESCRIPTION
        With no tag, the sum of every add. With tags, the sum of the adds made
        under all of those tags, whatever other tags they carry: after
        Add-Tally 5 -Tag A, B and Add-Tally 3 -Tag A, Get-Tally -Tag A returns 8
        and Get-Tally -Tag A, B returns 5. The order and case of the tags do not
        matter. A tag that nothing was added under reads as zero rather than an
        error, so a caller does not have to declare its tags first.

        Every add is looked at, so a read costs in proportion to how many
        different sets of tags were added under.

        A sum that does not fit a [long] ends the call with a terminating error
        rather than returning a wrong number.
    .PARAMETER Tag
        The tags an add must carry to be counted. A null, empty or blank tag is
        refused rather than taken to mean no tag. Omit it for the total.
    .INPUTS
        None.
    .OUTPUTS
        System.Int64. The sum.
    .EXAMPLE
        Add-Tally 5 -Tag A, B
        Add-Tally 3 -Tag A
        Get-Tally

        Returns 8, the sum of both adds.
    .EXAMPLE
        Get-Tally -Tag A, B

        Returns 5, the adds that carry both tags.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/README.md
    .LINK
        Add-Tally
    .LINK
        Clear-Tally
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Position = 0)]
        [Alias('Tags')]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern(
            '^\S([^\r\n\u0085\u2028\u2029\u000B\u000C]*\S)?\z',
            ErrorMessage = 'A tag is one line with no space at either end.')]
        [string[]]$Tag
    )

    $ErrorActionPreference = 'Stop'

    $state = Get-TallyState
    [Monitor]::Enter($state)
    try {
        $total = [long]0
        foreach ($key in (Get-TallyKey -State $state -Tag $Tag)) {
            $total = [long]([decimal]$total + $state[$key])
        }
    }
    finally {
        [Monitor]::Exit($state)
    }

    return $total
}
