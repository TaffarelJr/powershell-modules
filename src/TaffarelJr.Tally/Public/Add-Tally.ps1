using namespace System.Threading

function Add-Tally {
    <#
    .SYNOPSIS
        Adds to a named counter, creating it at zero first if it is new.
    .DESCRIPTION
        The module assigns no meaning to a name -
        "passed", "failed", a file extension,
        anything a caller chooses becomes its own counter,
        so long as it is one line with no leading or trailing whitespace.
        Names are not case-sensitive, like a hashtable's keys, and a counter
        keeps the spelling it was first added with.

        Names can be piped in, each one adding -Amount:
        $extensions | Add-Tally counts how often each appears.
        A piped object is counted by its Name property, and adds its Count
        property when it has one, so Read-Tally's, Get-Tally's or
        Group-Object's output adds each entry at its own count. A dictionary
        entry is counted once under its key.

        Counters are process-wide and safe to add to from any runspace.
        They last as long as the process does: removing or re-importing the
        module, or importing it in a new runspace, keeps every count.
        Only Clear-Tally resets them, so a script that needs to start from
        zero starts with Clear-Tally (or Clear-Tally -Key with its own key).
        Anything meant to be used by other code should pass -Key, so it
        cannot add to or clear a name someone else chose.

        A name that cannot be counted, or an add that would overflow, ends
        the call with a terminating error. In a pipeline the names before it
        are already counted, and the ones after it are not.
    .PARAMETER Name
        The counter to add to: a name, or an object whose Name property
        holds one. An object with no Name property is refused rather than
        counted under its own text.
    .PARAMETER Amount
        How much to add, as a whole number; a fraction is rounded to the
        nearest one, a half to the even neighbor. Defaults to one.
        A negative value decrements, since the module enforces no meaning
        on the running count. A count is a [long], and an add that would
        take it past what a [long] holds is refused, leaving it unchanged.
        Taken from a piped object's Count property when it has one: a Count
        of $null adds nothing (a new counter is still created, at zero), and
        a Count that is not a number is a binding error on -Amount.
    .PARAMETER Key
        Isolates this counter under its own namespace, so a caller
        can use a name like "passed" without adding to the same
        running count as anyone else who also uses it.
        Keys, like names, are not case-sensitive.
        Omit it for the shared, global counters; a $null, empty or blank
        key is refused rather than taken to mean those.
    .INPUTS
        System.Object. A name, or an object with a Name property and, when it
        should add more than one, a Count property.
    .OUTPUTS
        None. The counters change; nothing is written.
    .EXAMPLE
        Add-Tally -Name 'passed'
        Add-Tally -Name 'failed' -Amount 3

        Adds one to the passed counter and three to the failed one.
    .EXAMPLE
        Add-Tally -Name 'passed' -Key 'MyModule'

        Adds one to a passed counter that belongs to MyModule alone.
    .EXAMPLE
        Get-ChildItem -File | Where-Object Extension |
            ForEach-Object Extension | Add-Tally

        Counts the files in the current folder by extension, leaving out
        files with none.
    .EXAMPLE
        $line | Read-Tally | Add-Tally

        Merges a tally line printed by another process into this one's
        counters, each entry at its own count.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/README.md
    .LINK
        Get-Tally
    .LINK
        Clear-Tally
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Changes counters this module keeps in memory; nothing outside the process changes.')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Name,

        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [Alias('Count')]
        [long]$Amount = 1,

        [ValidatePattern(
            '\S',
            ErrorMessage = 'A tally key must hold a non-blank character; omit -Key for the global counters.'
        )]
        [string]$Key
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            $state = Get-TallyState
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            $resolved = Resolve-TallyName -InputObject $Name
            [Monitor]::Enter($state)
            try {
                $tallies = Get-TallyBucket -Key $Key -Create
                $current = [long]0
                if ($tallies.Contains($resolved)) {
                    $current = $tallies[$resolved].Count
                }

                $sum = [decimal]$current + $Amount
                if ($sum -gt [long]::MaxValue -or $sum -lt [long]::MinValue) {
                    throw "Adding $Amount to the tally '$resolved' would overflow its count of $current." +
                        ' Clear it first, or add a smaller amount.'
                }

                if (-not $tallies.Contains($resolved)) {
                    $tallies[$resolved] = [PSCustomObject]@{
                        Name  = $resolved
                        Count = [long]0
                    }
                }

                $tallies[$resolved].Count = [long]$sum
            }
            finally {
                [Monitor]::Exit($state)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
