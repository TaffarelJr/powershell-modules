using namespace System.Collections.Generic

function Add-Tally {
    <#
    .SYNOPSIS
        Adds to the count of each tag you give.
    .DESCRIPTION
        Every tag is a counter of its own: Add-Tally 5 -Tag A, B adds 5 to A and
        5 to B, so adding under several tags is a shortcut for adding the same
        amount to several counters. An add with no tag goes to the default
        counter, named (untagged).

        The module assigns no meaning to a tag: a category such as "passed", a
        file extension, and the id of a run are all just tags. To count along
        a second dimension, put it in the tag, as in "run 42:passed". Tags are
        dimensions to count along, not identifiers; a tag that is different on
        every add makes every add its own counter in memory.

        Names are not case-sensitive, and a counter keeps the spelling it was
        first added with. A tag repeated in one call is added to once.

        The counts are kept for the whole process and are safe to add to from
        any runspace. They last as long as the process does: removing or
        importing the module again, or importing it in another runspace, keeps
        every count. Only Clear-Tally resets them. Counts do not pass between
        processes; Get-Tally returns them as data to hand over.

        An add that would take a count past what a [long] holds is refused with
        a terminating error, and changes no count at all, the counts of its
        other tags included.
    .PARAMETER Amount
        How much to add, as a whole number. Defaults to 1. A negative amount
        takes away.
    .PARAMETER Tag
        The tags to add under: one line each, with no space at either end. A
        null, empty or blank tag is refused. Omit it to add to the default
        counter.
    .INPUTS
        None.
    .OUTPUTS
        None. The counts are kept; nothing is written.
    .EXAMPLE
        Add-Tally 5 -Tag A, B
        Add-Tally 3 -Tag A
        Get-Tally -Tag A

        Returns the pair A with the value 8: both adds went to A.
    .EXAMPLE
        Add-Tally -Tag passed, 'run 42:passed'

        Adds one to passed and to "run 42:passed".
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
            '^\S([^\r\n\u0085\p{Zl}\p{Zp}\u000B\u000C]*\S)?\z',
            ErrorMessage = 'A tag is one line with no space at either end.')]
        [string[]]$Tag
    )

    $ErrorActionPreference = 'Stop'

    $names = @($script:UntaggedName)
    if ($PSBoundParameters.ContainsKey('Tag')) {
        $names = $Tag
    }

    $seen = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $increments = [List[object]]::new()
    foreach ($name in $names) {
        if ($seen.Add($name)) {
            $increments.Add([PSCustomObject]@{ Name = $name; Value = $Amount })
        }
    }

    Add-TallyAmount -Increment $increments
}
