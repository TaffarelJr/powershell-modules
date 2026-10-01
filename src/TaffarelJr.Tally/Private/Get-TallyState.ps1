using namespace System.Threading

function Get-TallyState {
    <#
    .SYNOPSIS
        Returns the process-wide record of every counter.
    .DESCRIPTION
        Not exported. Process-wide rather than module state because every
        runspace that imports this module gets its own copy of that, so a
        count added from a ForEach-Object -Parallel runspace would land in a
        tally nobody else reads. It lives in the AppDomain, where they all
        see the same one, and is created under a lock so runspaces arriving
        together cannot each create their own. Callers lock the returned
        state itself while they read or change it.

        The data slot's name carries the version of the state's shape, so
        two versions of this module loaded into one process, with different
        shapes, never read each other's record.
    .OUTPUTS
        A hashtable: Global (the shared counters) and Keyed (the counters of
        each -Key, by key). A set of counters is an ordered dictionary from
        name to an object holding that name's first spelling and its count.
    #>
    [CmdletBinding()]
    param()

    $key = 'TaffarelJr.Tally.State.v1'
    $domain = [AppDomain]::CurrentDomain
    $state = $domain.GetData($key)
    if ($null -ne $state) {
        return $state
    }

    # Any code can lock the AppDomain, but it is held here only for one
    # read and write of the slot, so other code taking it waits a moment.
    [Monitor]::Enter($domain)
    try {
        $state = $domain.GetData($key)
        if ($null -eq $state) {
            $state = @{
                Global = [ordered]@{}
                Keyed  = @{}
            }

            $domain.SetData($key, $state)
        }
    }
    finally {
        [Monitor]::Exit($domain)
    }

    return $state
}
