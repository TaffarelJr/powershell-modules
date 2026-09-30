function Push-Indent {
    <#
    .SYNOPSIS
        Starts an indented region -
        every writer below it picks up the new indent automatically,
        with no need to pass it around.
    .DESCRIPTION
        Adds a level to the indent this module keeps for the current
        runspace, and writes nothing. Every line the module's writers print
        after it is that much further in, until Pop-Indent takes the level
        off again. Invoke-Indented does both around a script block.
    .PARAMETER Width
        Spaces added by this level: 2 unless given,
        the value the exported DefaultIndentWidth shows.
        Pop-Indent removes exactly this value,
        so nested levels can each use a different width safely.
    .INPUTS
        None.
    .OUTPUTS
        None. The indent grows; nothing is returned.
    .EXAMPLE
        Push-Indent
        Write-Info 'nested line'
        Pop-Indent

        Prints the line one level in, then puts the indent back.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Pop-Indent
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Changes the indentation this module keeps in memory; nothing outside the process changes.')]
    param(
        [Parameter(Position = 0)]
        [ValidateRange('NonNegative')]
        [int]$Width = $script:IndentWidth
    )

    try {
        $ErrorActionPreference = 'Stop'

        $script:IndentStack.Push($Width)
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
