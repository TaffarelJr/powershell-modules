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
    .EXAMPLE
        Add-Tally -Name 'passed'
        Add-Tally -Name 'failed' -Amount 3
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Position = 1)]
        [int]$Amount = 1
    )

    if (-not $script:Tallies.Contains($Name)) {
        $script:Tallies[$Name] = 0
    }

    $script:Tallies[$Name] += $Amount
}
