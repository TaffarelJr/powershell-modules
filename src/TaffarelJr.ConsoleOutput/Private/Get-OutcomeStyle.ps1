function Get-OutcomeStyle {
    <#
    .SYNOPSIS
        Returns how one outcome is written: its default wording, its color,
        and the marker it has on a line of its own.
    .DESCRIPTION
        Not exported. The one place each outcome's look is stated, read by
        the line writers and by whatever closes a Write-Doing line, so a
        color or a marker cannot drift between them. The table is built once,
        the first time it is asked for.
    .PARAMETER Outcome
        Success, Skip, Warn, Failure, Info, Detail, or Stopped.
    .OUTPUTS
        An object with Wording, Color, Marker, and Continuation: the spaces
        that carry a later line of a message past the marker.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Success', 'Skip', 'Warn', 'Failure', 'Info', 'Detail', 'Stopped')]
        [string]$Outcome
    )

    if ($null -eq $script:OutcomeStyles) {
        $rows = @(
            @{ Name = 'Success'; Wording = 'done'; Color = 'Green'; Marker = '✅ ' }
            @{ Name = 'Skip'; Wording = 'already done'; Color = 'DarkGray'; Marker = '⏭️  ' }
            @{ Name = 'Warn'; Wording = 'warning'; Color = 'Yellow'; Marker = '⚠️  ' }
            @{ Name = 'Failure'; Wording = 'failed'; Color = 'Red'; Marker = '❌ ' }
            @{ Name = 'Info'; Wording = ''; Color = 'Gray'; Marker = 'ℹ️  ' }
            @{ Name = 'Detail'; Wording = ''; Color = 'DarkGray'; Marker = '   ' }
            @{ Name = 'Stopped'; Wording = 'stopped'; Color = 'Yellow'; Marker = '⚠️  ' }
        )
        $styles = @{}
        foreach ($row in $rows) {
            $styles[$row.Name] = [PSCustomObject]@{
                Wording      = $row.Wording
                Color        = [ConsoleColor]$row.Color
                Marker       = $row.Marker
                Continuation = '   '
            }
        }

        $script:OutcomeStyles = $styles
    }

    return $script:OutcomeStyles[$Outcome]
}
