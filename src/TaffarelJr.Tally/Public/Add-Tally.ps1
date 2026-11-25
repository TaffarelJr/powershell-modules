using namespace System.Collections
using namespace System.Collections.Generic

function Add-Tally {
    <#
    .SYNOPSIS
        Adds to the count of each tag you give, or merges counts in.
    .DESCRIPTION
        Every tag is a counter of its own: Add-Tally 5 -Tag A, B adds 5 to A and
        5 to B, so adding under several tags is a shortcut for adding the same
        amount to several counters. An add with no tag goes to the default
        counter, named (untagged), which a tag of that name also reaches.

        The module assigns no meaning to a tag: a category such as "passed", a
        file extension, and the id of a run are all just tags. To count along
        a second dimension, put it in the tag, as in "run 42:passed". Tags are
        dimensions to count along, not identifiers; a tag that is different on
        every add makes every add its own counter in memory.

        With -Counts, or with input from the pipeline, it merges counts that
        were kept somewhere else: a dictionary of counts, or pairs, each added
        to its counter. What Get-Tally returns goes straight back in, so
        Get-Tally | ConvertTo-Json in one process and ConvertFrom-Json |
        Add-Tally in another hands the counts over. A pair is an object with a
        Name or Key and a Value or Count, as a dictionary entry or what
        Group-Object writes is. Each count must be a whole number, an integer
        that fits a [long]; a fraction or a number written as text is refused.
        A dictionary is merged all or nothing. Pairs piped in are merged one at
        a time, so a bad one stops the merge with the pairs before it already
        added.

        Names are not case-sensitive, and a counter keeps the spelling it was
        first added with. A tag repeated in one call is added to once.

        The counts are kept for the whole process and are safe to add to from
        any runspace. They last as long as the process does: removing or
        importing the module again, or importing it in another runspace, keeps
        every count. Only Clear-Tally resets them. Counts do not pass between
        processes except by being merged in.

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
    .PARAMETER Counts
        The counts to merge in: a dictionary of counts, a pair, or several
        pairs. Cannot be combined with -Amount or -Tag.
    .INPUTS
        System.Object. A dictionary of counts, or a pair; each is merged in
        turn.
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
    .EXAMPLE
        $json | ConvertFrom-Json | Add-Tally

        Merges counts another process printed with Get-Tally | ConvertTo-Json.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/README.md
    .LINK
        Get-Tally
    .LINK
        Clear-Tally
    #>
    [CmdletBinding(DefaultParameterSetName = 'Event')]
    param(
        [Parameter(ParameterSetName = 'Event', Position = 0)]
        [long]$Amount = 1,

        [Parameter(ParameterSetName = 'Event', Position = 1)]
        [Alias('Tags')]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern(
            '^\S([^\r\n\u0085\p{Zl}\p{Zp}\u000B\u000C]*\S)?\z',
            ErrorMessage = 'A tag is one line with no space at either end.')]
        [string[]]$Tag,

        [Parameter(Mandatory, ParameterSetName = 'Merge', ValueFromPipeline)]
        [AllowEmptyCollection()]
        [object]$Counts
    )

    process {
        $ErrorActionPreference = 'Stop'

        if ($PSCmdlet.ParameterSetName -eq 'Merge') {
            $entries = @($Counts)
            if ($Counts -is [IDictionary]) {
                $entries = @($Counts.GetEnumerator())
            }

            $merged = foreach ($entry in $entries) {
                Resolve-TallyEntry -InputObject $entry
            }

            if (@($merged).Count -gt 0) {
                Add-TallyAmount -Increment $merged
            }

            return
        }

        $names = @($script:UntaggedName)
        if ($PSBoundParameters.ContainsKey('Tag')) {
            $names = $Tag
        }

        $seen = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $increments = [List[object]]::new()
        foreach ($name in $names) {
            if ($seen.Add($name)) {
                $increment = [PSCustomObject]@{ Name = $name; Value = $Amount }
                $increments.Add($increment)
            }
        }

        Add-TallyAmount -Increment $increments
    }
}
