using namespace System.Threading

function Add-Tally {
    <#
    .SYNOPSIS
        Adds to the tally, under any tags you give it.
    .DESCRIPTION
        An add is an amount and a set of tags. Get-Tally sums the adds that
        carry the tags you ask for, so one add can be counted along several
        dimensions at once: with Add-Tally 5 -Tag A, B, then Add-Tally 3 -Tag A
        and Add-Tally 1 -Tag B, Get-Tally returns 9, Get-Tally -Tag A returns
        8 and Get-Tally -Tag B returns 6.

        The module assigns no meaning to a tag: a category such as "passed", a
        file extension, or the id of one run are all just tags. Tags are
        dimensions to sum along, not identifiers; a tag that is different on
        every add makes every add its own entry in memory.

        The tags of an add are a set: their order, their case and a repeated
        tag do not matter. An add with no tag counts toward the total only.

        The tally is kept for the whole process and is safe to add to from any
        runspace. It lasts as long as the process does: removing or importing
        the module again, or importing it in another runspace, keeps every
        count. Only Clear-Tally resets it. Counts do not pass between
        processes; to carry one over, print it and add it in the other.

        An add that would take a count past what a [long] holds is refused with
        a terminating error and leaves the count as it was.
    .PARAMETER Amount
        How much to add, as a whole number. Defaults to 1. A negative amount
        takes away.
    .PARAMETER Tag
        The tags to add under: one line each, with no space at either end. A
        null, empty or blank tag is refused. Omit it to add to the total only.
    .INPUTS
        None.
    .OUTPUTS
        None. The count is kept; nothing is written.
    .EXAMPLE
        Add-Tally 5 -Tag A, B
        Add-Tally 3 -Tag A
        Add-Tally 1 -Tag B
        Get-Tally -Tag A

        Returns 8: the first two adds carry the tag A.
    .EXAMPLE
        Add-Tally -Tag passed, 'run 42'

        Adds one under the tags passed and "run 42".
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/README.md
    .LINK
        Get-Tally
    .LINK
        Clear-Tally
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [long]$Amount = 1,

        [Parameter(Position = 1)]
        [Alias('Tags')]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern(
            '^\S([^\r\n\u0085\u2028\u2029\u000B\u000C]*\S)?\z',
            ErrorMessage = 'A tag is one line with no space at either end.')]
        [string[]]$Tag
    )

    $ErrorActionPreference = 'Stop'

    $state = Get-TallyState
    $key = ConvertTo-TallyKey -Tag $Tag
    [Monitor]::Enter($state)
    try {
        $current = [long]0
        $null = $state.TryGetValue($key, [ref]$current)
        $state[$key] = [long]([decimal]$current + $Amount)
    }
    finally {
        [Monitor]::Exit($state)
    }
}
