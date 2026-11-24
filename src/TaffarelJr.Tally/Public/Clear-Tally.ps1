using namespace System.Threading

function Clear-Tally {
    <#
    .SYNOPSIS
        Removes the adds that carry every tag you give, or every add.
    .DESCRIPTION
        With no tag, removes every add, untagged ones included. With tags,
        removes the adds made under all of those tags, whatever other tags they
        carry: after Add-Tally 5 -Tag A, B, Add-Tally 3 -Tag A and
        Add-Tally 1 -Tag B, Clear-Tally -Tag A leaves 1, and Clear-Tally -Tag
        A, B leaves 4. Clearing tags that nothing was added under changes
        nothing and is not an error.
    .PARAMETER Tag
        The tags an add must carry to be removed. A null, empty or blank tag is
        refused rather than taken to mean no tag, so a variable that turned out
        empty cannot clear everything. Omit it to remove every add.
    .INPUTS
        None.
    .OUTPUTS
        None. The adds are removed; nothing is written.
    .EXAMPLE
        Clear-Tally

        Removes every add, so a script that needs to start from zero can begin
        here.
    .EXAMPLE
        Clear-Tally -Tag 'run 42'

        Removes the adds made under the tag "run 42".
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
            '^\S([^\r\n\u0085\u2028\u2029\u000B\u000C]*\S)?\z',
            ErrorMessage = 'A tag is one line with no space at either end.')]
        [string[]]$Tag
    )

    $ErrorActionPreference = 'Stop'

    $state = Get-TallyState
    [Monitor]::Enter($state)
    try {
        foreach ($key in (Get-TallyKey -State $state -Tag $Tag)) {
            $null = $state.Remove($key)
        }
    }
    finally {
        [Monitor]::Exit($state)
    }
}
