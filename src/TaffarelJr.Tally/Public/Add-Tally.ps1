function Add-Tally {
    <#
    .SYNOPSIS
        Adds to a named counter, creating it at zero first if it is new.
    .DESCRIPTION
        The module assigns no meaning to a name -
        "passed", "failed", a file extension,
        anything a caller chooses becomes its own counter.
    .PARAMETER Name
        The counter to add to.
    .PARAMETER Amount
        How much to add. Defaults to one. A negative value decrements,
        since the module enforces no meaning on the running count.
    .PARAMETER Key
        Isolates this counter under its own namespace, so a caller
        can use a name like "passed" without adding to the same
        running count as anyone else who also uses it.
        Omit it for the shared, global counters.
    .EXAMPLE
        Add-Tally -Name 'passed'
        Add-Tally -Name 'failed' -Amount 3
    .EXAMPLE
        Add-Tally -Name 'passed' -Key 'MyModule'
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Position = 1)]
        [int]$Amount = 1,

        [string]$Key
    )

    $tallies = Get-TallyBucket -Key $Key

    if (-not $tallies.Contains($Name)) {
        $tallies[$Name] = 0
    }

    $tallies[$Name] += $Amount
}
