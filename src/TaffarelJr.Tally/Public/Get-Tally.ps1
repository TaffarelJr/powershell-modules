using namespace System.Collections.Generic
using namespace System.Threading

function Get-Tally {
    <#
    .SYNOPSIS
        Returns the count of each tag as a name and a value.
    .DESCRIPTION
        With no tag, every counter: the default counter, (untagged), first,
        then the others sorted without regard to case. The default counter is
        always there, at zero until something untagged is added.

        With tags, only those counters, in the order given, a repeated tag
        once. A tag nothing was added under is left out rather than listed at
        zero. A tag comes back spelled as you gave it.

        Each result is an object with a Name and a Value, a [long]. They are
        data, so the caller decides what to do with them: sort or filter them,
        add up the ones that belong together, pipe them to Show-FieldList in
        TaffarelJr.ConsoleOutput, or to ConvertTo-Json to hand them to another
        process. Add-Tally reads them back. Add up counts as [long] values:
        Measure-Object -Sum returns a [double], which loses digits near the top
        of a [long].
    .PARAMETER Tag
        The tags to read. A null, empty or blank tag is refused rather than
        taken to mean every counter. Omit it for all of them.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject. One for each counter, with
        a Name and a Value.
    .EXAMPLE
        Add-Tally 5 -Tag A, B
        Add-Tally 3 -Tag A
        Get-Tally

        Returns (untagged) with 0, A with 8, and B with 5.
    .EXAMPLE
        Get-Tally -Tag B, A, Z

        Returns B with 5 and A with 8, in that order; Z was never added.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/README.md
    .LINK
        Add-Tally
    .LINK
        Clear-Tally
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0)]
        [Alias('Tags')]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern(
            '^\S([^\r\n\u0085\p{Zl}\p{Zp}\u000B\u000C]*\S)?\z',
            ErrorMessage = 'A tag is one line with no space at either end.')]
        [string[]]$Tag
    )

    $ErrorActionPreference = 'Stop'

    $untagged = $script:UntaggedName
    $pairs = [List[object]]::new()
    $state = Get-TallyState
    [Monitor]::Enter($state)
    try {
        $value = [long]0
        if ($PSBoundParameters.ContainsKey('Tag')) {
            $asked = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($name in $Tag) {
                $found = $state.TryGetValue($name, [ref]$value)
                if ($asked.Add($name) -and ($found -or $name -ieq $untagged)) {
                    $pairs.Add([PSCustomObject]@{ Name = $name; Value = $value })
                }
            }
        }
        else {
            $null = $state.TryGetValue($untagged, [ref]$value)
            $pairs.Add([PSCustomObject]@{ Name = $untagged; Value = $value })

            $comparer = [StringComparer]::OrdinalIgnoreCase
            $names = [SortedSet[string]]::new($comparer)
            foreach ($key in $state.PSBase.Keys) {
                if ($key -ine $untagged) {
                    $null = $names.Add($key)
                }
            }

            foreach ($name in $names) {
                $count = $state[$name]
                $pairs.Add([PSCustomObject]@{ Name = $name; Value = $count })
            }
        }
    }
    finally {
        [Monitor]::Exit($state)
    }

    Write-Output $pairs
}
