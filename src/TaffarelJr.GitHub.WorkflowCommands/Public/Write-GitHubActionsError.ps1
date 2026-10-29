function Write-GitHubActionsError {
    <#
    .SYNOPSIS
        Writes an error annotation, shown inline on the run and on any
        pull request it belongs to.
    .DESCRIPTION
        This only annotates the log - it does not fail the step or the
        job. Throw, or exit non-zero, to actually fail it.

        A position the runner would move or drop without a word throws
        instead: an end line or end column without its start, a column
        without a line or on a range of several lines, or an end before
        its start.

        A piped object can carry the message and its position in
        properties named after the parameters, such as Message, File, and
        Line; an object without a Message property throws. A piped position
        must be a whole number of a numeric type, and a piped property that
        holds nothing usable - $null, blank, 0, a fraction, or text - is left
        out; the same value given on the command line throws, though there
        whole-number text counts. A Select-String match annotates its file
        at its line number with the matched line, so
        Select-String TODO *.ps1 | Write-GitHubActionsError
        marks each match where it is.
    .PARAMETER Message
        The text to show. Also taken from a piped string, a piped
        Select-String match's line, a piped error record's message, or a
        piped object's Message property.
    .PARAMETER File
        The file the annotation points at, relative to the repository
        root, or a full path within the workspace, which the runner makes
        relative.
    .PARAMETER Line
        The line the annotation points at, counting from 1.
    .PARAMETER EndLine
        The last line of the range, not before -Line. Needs -Line; omit to
        point at a single line.
    .PARAMETER Column
        The column the annotation points at, counting from 1. Needs -Line,
        and applies within a single line only. Also accepted as -Col.
    .PARAMETER EndColumn
        The last column of the range, not before -Column. Needs -Column;
        omit to point at a single column.
    .PARAMETER Title
        A short heading shown above the message.
    .INPUTS
        System.Object. A string, a Select-String match, an error record, or
        an object with a Message property; an object can also carry File,
        Line, EndLine, Column, EndColumn, and Title properties.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Write-GitHubActionsError -Message 'Build failed' -File 'app.ps1' -Line 9

        Shows the message on line 9 of the file, inline on the run and on any
        pull request it belongs to.
    .EXAMPLE
        try { Invoke-Build } catch { $_ | Write-GitHubActionsError }

        Annotates the run with the message of the error that was caught.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    .LINK
        Write-GitHubActionsWarning
    .LINK
        Write-GitHubActionsNotice
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [object]$Message,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$File,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$Line,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$EndLine,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Col')]
        [object]$Column,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$EndColumn,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$Title
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            $messageGiven = $PSBoundParameters.ContainsKey('Message')
            $given = [ordered]@{}
            foreach ($key in 'File', 'Line', 'EndLine', 'Column', 'EndColumn', 'Title') {
                if ($PSBoundParameters.ContainsKey($key)) {
                    $bound = $PSBoundParameters.$key
                    $given.$key = ConvertTo-GitHubActionsAnnotationValue -Name $key -Value $bound -Strict
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            $annotation = @{
                Command   = 'error'
                Message   = $Message
                File      = $File
                Line      = $Line
                EndLine   = $EndLine
                Column    = $Column
                EndColumn = $EndColumn
                Title     = $Title
                Given     = @($given.PSBase.Keys)
            }

            foreach ($name in $given.PSBase.Keys) {
                $annotation[$name] = $given[$name]
            }

            if ($messageGiven) {
                $annotation['Message'] = [string]$Message
            }

            Write-GitHubActionsAnnotation @annotation
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
