using namespace System.Threading

function Get-TestTally {
    <#
    .SYNOPSIS
        Returns the process-wide pass/fail tally.
    .DESCRIPTION
        Not exported. Process-wide rather than module state because every
        runspace that imports this module gets its own copy of that: an
        assertion made from a ForEach-Object -Parallel runspace would be
        counted into a tally nobody reads. It lives in the AppDomain, where
        they all see the same one, and is created under a lock so runspaces
        arriving together cannot each create their own.

        The data slot's name carries the version of the state's shape, so
        two versions of this module loaded into one process, with different
        shapes, never read each other's tally.
    .OUTPUTS
        A hashtable: Passed and Failed.
    #>
    param()

    $key = 'TaffarelJr.TestKit.Tally.v1'
    $domain = [AppDomain]::CurrentDomain
    $tally = $domain.GetData($key)
    if ($null -ne $tally) {
        return $tally
    }

    [Monitor]::Enter($domain)
    try {
        $tally = $domain.GetData($key)
        if ($null -eq $tally) {
            $tally = @{
                Passed = 0
                Failed = 0
            }

            $domain.SetData($key, $tally)
        }
    }
    finally {
        [Monitor]::Exit($domain)
    }

    return $tally
}
