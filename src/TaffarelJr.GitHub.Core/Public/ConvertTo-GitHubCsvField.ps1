function ConvertTo-GitHubCsvField {
    <#
    .SYNOPSIS
        Returns each value as one CSV field, the form gh reads every value
        of a list flag in.
    .DESCRIPTION
        gh reads each value of a list flag - --label, --assignee,
        --project, --reviewer, and their --add-/--remove- forms - as one
        line of CSV, so a comma splits it into two values and a double
        quote in the wrong place fails the whole command with a usage
        error. A value holding a comma, a double quote, or a line break is
        therefore wrapped in double quotes, with each double quote inside
        it doubled; any other value is returned unchanged.
    .PARAMETER Value
        The values, one per flag occurrence.
    .INPUTS
        None
    .OUTPUTS
        System.String
        One CSV field per value, in order.
    .EXAMPLE
        $labels = ConvertTo-GitHubCsvField -Value 'bug, urgent', 'docs'
        $arguments = foreach ($label in $labels) { '--label', $label }

        Gives --label '"bug, urgent"' --label docs, so gh adds the two
        labels 'bug, urgent' and 'docs'.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Value
    )

    try {
        $ErrorActionPreference = 'Stop'

        foreach ($item in $Value) {
            if ($item.IndexOfAny([char[]]",`"`r`n") -lt 0) {
                $item
            }
            else {
                '"' + $item.Replace('"', '""') + '"'
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
