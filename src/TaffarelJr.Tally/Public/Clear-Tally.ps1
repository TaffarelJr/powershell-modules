using namespace System.Threading

function Clear-Tally {
    <#
    .SYNOPSIS
        Resets one counter, or every counter.
    .DESCRIPTION
        Clearing a name that was never added is a no-op, not an error -
        the module keeps no sense of which names are "valid" to clear.
        A name no counter could have, such as an empty one, is refused.
        A key is forgotten once it has no counters left, whether its whole
        set was cleared at once or its last name was cleared on its own,
        so a caller that makes up a key per run does not leave them behind.

        A name that cannot be a counter's ends the call with a terminating
        error. In a pipeline the counters before it are already cleared, and
        the ones after it are not.
    .PARAMETER Name
        The counter to remove: a name, or an object whose Name property
        holds one. Names can be piped in, so Get-Tally's output can be.
        Omit it to remove every counter instead.
    .PARAMETER Key
        Clears this namespace instead of the shared, global counters -
        see Add-Tally. A $null, empty or blank key is refused rather than
        taken to mean the global counters.
    .INPUTS
        System.Object. A name, or an object with a Name property, such as
        Get-Tally's output.
    .OUTPUTS
        None. The counters are removed; nothing is written.
    .EXAMPLE
        Clear-Tally -Name 'passed'

        Removes the passed counter, so it reads zero again.
    .EXAMPLE
        Clear-Tally

        Removes every shared counter.
    .EXAMPLE
        Clear-Tally -Key 'MyModule'

        Removes every counter that belongs to MyModule, and the key with them.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/README.md
    .LINK
        Add-Tally
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Clears counters this module keeps in memory; nothing outside the process changes.')]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$Name,

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
            $byName = $PSBoundParameters.ContainsKey('Name')
            $resolved = $null
            if ($byName) {
                $resolved = Resolve-TallyName -InputObject $Name
            }

            [Monitor]::Enter($state)
            try {
                $tallies = Get-TallyBucket -Key $Key
                if ($null -eq $tallies) {
                    return
                }

                if ($byName) {
                    $tallies.Remove($resolved)
                }
                else {
                    $tallies.Clear()
                }

                if ($tallies.Count -eq 0) {
                    $state.Keyed.Remove($Key)
                }
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
