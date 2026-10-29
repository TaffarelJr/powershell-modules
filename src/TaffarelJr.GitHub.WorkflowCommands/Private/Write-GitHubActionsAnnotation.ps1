function Write-GitHubActionsAnnotation {
    <#
    .SYNOPSIS
        Writes a notice, warning, or error annotation.
    .DESCRIPTION
        Not exported. Shared by Write-GitHubActionsNotice, -Warning, and
        -Error, which differ only in which workflow command they name. A
        property that holds nothing usable - $null, blank, 0, or text where
        a number belongs - is left out of the command: that is what a
        parameter holds when it was not given, and what a piped record may
        hold in a property of the same name. The public functions refuse
        such a value given on the command line before it gets here.

        The message is a string as given. A Select-String match annotates
        its file (unless it searched piped text) at its line number with the
        matched line's text, for each of the file and line not given on the
        command line; its Line property, the matched text, is never a
        position. An error record gives its message. Any other object gives
        its Message property's text, and throws without one.

        A position the runner would move or drop without a word - an end
        without its start, columns without a line or across several lines,
        an end before its start - throws instead, naming the problem.
    .PARAMETER Command
        The workflow command: notice, warning, or error.
    .PARAMETER Message
        The annotation's text, or the piped object that carries it.
    .PARAMETER Given
        The names of the parameters given on the command line, which a
        Select-String match does not override.
    .PARAMETER File
        The file the annotation points at.
    .PARAMETER Line
        The first line.
    .PARAMETER EndLine
        The last line.
    .PARAMETER Column
        The first column.
    .PARAMETER EndColumn
        The last column.
    .PARAMETER Title
        The annotation's heading.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [object]$Message,

        [AllowEmptyCollection()]
        [string[]]$Given = @(),

        [AllowNull()]
        [object]$File,

        [AllowNull()]
        [object]$Line,

        [AllowNull()]
        [object]$EndLine,

        [AllowNull()]
        [object]$Column,

        [AllowNull()]
        [object]$EndColumn,

        [AllowNull()]
        [object]$Title
    )

    # Named as text: the Utility commands' assembly that defines MatchInfo may
    # not be loaded yet in a new process, and a type literal would then throw.
    if ($Message.GetType().FullName -eq 'Microsoft.PowerShell.Commands.MatchInfo') {
        $match = $Message.PSObject.Properties
        if ('Line' -notin $Given) {
            $Line = $match['LineNumber'].Value
        }

        if ('File' -notin $Given) {
            $File = $null
            if ($match['Path'].Value -ne 'InputStream') {
                $File = $match['Path'].Value
            }
        }
    }

    $text = ConvertTo-GitHubActionsMessageText -Message $Message

    $File = ConvertTo-GitHubActionsAnnotationValue -Name 'File' -Value $File
    $Line = ConvertTo-GitHubActionsAnnotationValue -Name 'Line' -Value $Line
    $EndLine = ConvertTo-GitHubActionsAnnotationValue -Name 'EndLine' -Value $EndLine
    $Column = ConvertTo-GitHubActionsAnnotationValue -Name 'Column' -Value $Column
    $EndColumn = ConvertTo-GitHubActionsAnnotationValue -Name 'EndColumn' -Value $EndColumn
    $Title = ConvertTo-GitHubActionsAnnotationValue -Name 'Title' -Value $Title

    $hasLine = $null -ne $Line
    $hasEndLine = $null -ne $EndLine
    $hasColumn = $null -ne $Column
    $hasEndColumn = $null -ne $EndColumn

    if ($hasEndLine -and -not $hasLine) {
        throw ("-EndLine $EndLine was given without -Line, " +
            'which the runner would read as the start line instead: give -Line too.')
    }

    if ($hasEndColumn -and -not $hasColumn) {
        throw ("-EndColumn $EndColumn was given without -Column, " +
            'which the runner would read as the start column instead: give -Column too.')
    }

    if ($hasColumn -and -not $hasLine) {
        throw '-Column was given without -Line, so the runner would drop the columns: give -Line too.'
    }

    if ($hasColumn -and $hasEndLine -and $EndLine -ne $Line) {
        throw ("Columns point within a single line, but -Line $Line and -EndLine $EndLine differ, " +
            'so the runner would drop the columns: leave out the columns or the end line.')
    }

    if ($hasEndLine -and $EndLine -lt $Line) {
        throw "-EndLine $EndLine is before -Line $Line, so the runner would drop both: swap them."
    }

    if ($hasEndColumn -and $EndColumn -lt $Column) {
        throw "-EndColumn $EndColumn is before -Column $Column, so the runner would drop both: swap them."
    }

    $properties = [ordered]@{}
    if ($File) {
        $properties['file'] = $File
    }

    if ($hasLine) {
        $properties['line'] = $Line
    }

    if ($hasEndLine) {
        $properties['endLine'] = $EndLine
    }

    if ($hasColumn) {
        $properties['col'] = $Column
    }

    if ($hasEndColumn) {
        $properties['endColumn'] = $EndColumn
    }

    if ($Title) {
        $properties['title'] = $Title
    }

    Write-GitHubActionsCommand -Command $Command -Properties $properties -Data $text
}
