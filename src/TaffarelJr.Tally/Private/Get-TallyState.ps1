using namespace System.Collections.Generic
using namespace System.Threading

function Get-TallyState {
    <#
    .SYNOPSIS
        Returns the process-wide record of every counter.
    .DESCRIPTION
        Not exported. Kept for the whole process rather than in module state,
        because every runspace that imports this module gets its own copy of
        that, so an add from a ForEach-Object -Parallel runspace would land in
        a tally nobody else reads. The record lives in the AppDomain, where
        every runspace sees the same one, and is created under a lock so
        runspaces arriving together cannot each create their own. Callers lock
        the returned record itself while they read or change it. The record is
        what Add-Tally, Get-Tally and Clear-Tally share.

        The slot's name carries the version of the record's shape, so two
        versions of this module loaded into one process, with different
        shapes, never read each other's record.
    .OUTPUTS
        A dictionary from a counter's name to its count. Names are not
        case-sensitive.
    #>
    [CmdletBinding()]
    [OutputType([Dictionary[string, long]])]
    param()

    $slot = 'TaffarelJr.Tally.State.v3'
    $domain = [AppDomain]::CurrentDomain
    $state = $domain.GetData($slot)
    if ($null -ne $state) {
        return $state
    }

    [Monitor]::Enter($domain)
    try {
        $state = $domain.GetData($slot)
        if ($null -eq $state) {
            $comparer = [StringComparer]::OrdinalIgnoreCase
            $state = [Dictionary[string, long]]::new($comparer)
            $domain.SetData($slot, $state)
        }
    }
    finally {
        [Monitor]::Exit($domain)
    }

    return $state
}
