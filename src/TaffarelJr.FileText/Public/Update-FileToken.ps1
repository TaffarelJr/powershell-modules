using namespace System.Diagnostics.CodeAnalysis

function Update-FileToken {
    <#
    .SYNOPSIS
        Replaces a token in one file's content, keeping its encoding and
        line ending.
    .DESCRIPTION
        The file is read once and written once, in the encoding it was read
        in, and its line endings are written as they were. The match is
        literal and case-sensitive, and every occurrence is replaced. A file
        without the token is left alone, whatever it holds.

        A file whose first 8 KB hold a NUL is binary content, which an
        extension list cannot recognize and rewriting as text would destroy.
        It is never decoded: its bytes are searched for the token, as UTF-8,
        UTF-16, and UTF-32. One that holds the token is declined with a
        warning, so declining is not mistaken for there being nothing to do.
        UTF-16 or UTF-32 text without a byte order mark is full of NULs and
        is declined the same way.

        Text that holds the token but is not valid in its encoding, such as
        Windows-1252 text read as UTF-8, throws and is left as it was:
        rewriting it would replace each such character for good.

        A file that cannot be updated is a terminating error for that call,
        and in a pipeline it stops the pipeline: files after it are not
        touched, and files before it stay updated.

        -WhatIf and -Confirm name each file that holds the token, once it has
        been read; a file without it is not named. With -WhatIf nothing is
        changed and nothing is returned, and with -Confirm a file declined at
        the prompt is left as it was and returns nothing.

        With -Verbose, names each file as it is written, with its size and
        encoding.
    .PARAMETER Path
        The file to update. A relative path is relative to PowerShell's
        current location. Path strings can be piped in, and so can files from
        Get-ChildItem (by their FullName or PSPath) and Resolve-Path output
        (by its Path). A folder, given or piped in, throws and so stops the
        pipeline: list files with Get-ChildItem -File.
    .PARAMETER From
        The token to replace. -WhatIf, -Confirm, -Verbose, and the warning for
        binary content show this text, so a secret should not be given where
        that output is kept.
    .PARAMETER To
        What to replace it with. Empty removes the token. No output shows it.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String. The path of a file; or any object with a FullName,
        PSPath, or Path property, such as the files Get-ChildItem returns.
    .OUTPUTS
        System.Boolean. Whether the file was rewritten, one per file. Nothing
        under -WhatIf, nor for a file declined at a -Confirm prompt.
    .EXAMPLE
        Update-FileToken -Path ./Program.cs -From 'OldName' -To 'NewName'

        Replaces the token in Program.cs, and returns $true if it held the
        token and $false if it did not.
    .EXAMPLE
        Get-ChildItem -File -Filter *.cs -Recurse |
            Update-FileToken -From 'OldName' -To 'NewName'

        Replaces the token in every C# file under the current folder, and
        returns one $true or $false for each.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.FileText/README.md
    .LINK
        Write-TextFile
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'Edit-TextFileToken asks this command''s ShouldProcess.')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidatePattern('\S')]
        [string]$From,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$To
    )

    process {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $status = Edit-TextFileToken -Path $Path -From $From -To $To `
            -Cmdlet $PSCmdlet
        if ($status -eq 'Binary') {
            $reason = "holds '$From' and a NUL, so it was not rewritten."
            Write-Warning "Skipped binary content: '$Path' $reason"
        }

        if ($WhatIfPreference -or $status -eq 'Declined') {
            return
        }

        return $status -eq 'Edited'
    }
}
