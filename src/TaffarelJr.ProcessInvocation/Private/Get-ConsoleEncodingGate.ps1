using namespace System.Threading

function Get-ConsoleEncodingGate {
    <#
    .SYNOPSIS
        Returns the process-wide record of who has the console encoding
        pinned.
    .DESCRIPTION
        Not exported. Process-wide because the console's encoding is, and a
        runspace's module state is not: every runspace that imports this
        module gets its own copy, so the record lives in the AppDomain,
        where they all see the same one. It is created under a lock so two
        runspaces arriving together cannot each create their own.
        The slot's name ends in the version of the record's shape, because
        two versions of this module in one process share the slot.
    .OUTPUTS
        A hashtable: Depth (how many calls hold the pin), Original (the
        output encoding to restore, or $null when the pin changed nothing),
        and OriginalInput (the same for the input encoding).
    #>
    param()

    $key = 'TaffarelJr.ProcessInvocation.ConsoleEncodingGate.v1'
    $domain = [AppDomain]::CurrentDomain
    $gate = $domain.GetData($key)
    if ($null -ne $gate) {
        return $gate
    }

    [Monitor]::Enter($domain)
    try {
        $gate = $domain.GetData($key)
        if ($null -eq $gate) {
            $gate = @{
                Depth         = 0
                Original      = $null
                OriginalInput = $null
            }

            $domain.SetData($key, $gate)
        }
    }
    finally {
        [Monitor]::Exit($domain)
    }

    return $gate
}
