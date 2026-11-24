using namespace System.Threading

function Clear-Tally {
    <#
    .SYNOPSIS
        Clears the count of each tag you give, or every count.
    .DESCRIPTION
        With no tag, clears every counter, the default counter included. With
        tags, clears only those: the counters are independent, so clearing A
        does not lower B, whatever was added under both. Clearing a tag
        nothing was added under changes nothing and is not an error.
    .PARAMETER Tag
        The tags to clear. A null, empty or blank tag is refused rather than
        taken to mean every counter, so a variable that turned out empty cannot
        clear everything. Omit it to clear every counter.
    .INPUTS
        None.
    .OUTPUTS
        None. The counts are cleared; nothing is written.
    .EXAMPLE
        Clear-Tally

        Clears every counter, so a script that needs to start from zero can
        begin here.
    .EXAMPLE
        Clear-Tally -Tag 'run 42:passed', 'run 42:failed'

        Clears the two counters of run 42.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/README.md
    .LINK
        Add-Tally
    .LINK
        Get-Tally
    #>
    [CmdletBinding()]
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

    $state = Get-TallyState
    [Monitor]::Enter($state)
    try {
        if ($PSBoundParameters.ContainsKey('Tag')) {
            foreach ($name in $Tag) {
                $null = $state.Remove($name)
            }
        }
        else {
            $state.Clear()
        }
    }
    finally {
        [Monitor]::Exit($state)
    }
}
