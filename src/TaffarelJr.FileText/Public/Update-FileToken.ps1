function Update-FileToken {
    <#
    .SYNOPSIS
        Replaces a token in one file's content,
        keeping its encoding and line ending.
    .DESCRIPTION
        Declines a file that holds the token and a NUL,
        which is the reliable mark of binary content:
        an extension deny-list cannot list every binary format,
        and rewriting one as text destroys it.
        It says so in a warning, so declining is not mistaken for there being
        nothing to do. UTF-16 or UTF-32 text without a byte order mark is full
        of NULs too, and is declined the same way.
        A file whose first 8 KB hold a NUL is never decoded as text at all:
        its bytes are searched for the token instead.

        Throws for a file that has the token but is not valid in its encoding,
        such as Windows-1252 text read as UTF-8: rewriting it would replace
        each such character for good. A file without the token is never read
        that closely, so it is left alone whatever it holds.

        A failing file is a terminating error for that call, and in a
        pipeline it stops the pipeline: files after it are not touched, and
        files before it stay updated.

        -WhatIf and -Confirm name each file that holds the token, once it has
        been read; a file without it is not named. With -Confirm a declined
        file is left as it was and returns nothing.
        With -WhatIf nothing is changed and nothing is returned.

        With -Verbose, names each file as it is written.
    .PARAMETER Path
        The file to update. A relative path is relative to PowerShell's current
        location. Path strings can be piped in, and so can files from
        Get-ChildItem (by their FullName or PSPath) and Resolve-Path output
        (by its Path). A folder, given or piped in, throws and so stops the
        pipeline: list files with Get-ChildItem -File.
    .PARAMETER From
        The token to replace.
        -WhatIf, -Confirm, -Verbose, and the warning for a binary file
        show this text, so a secret should not be given where that output
        is kept.
    .PARAMETER To
        What to replace it with. Empty removes the token.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String. The path of a file; or any object with a FullName,
        PSPath, or Path property, such as the files Get-ChildItem returns.
    .OUTPUTS
        System.Boolean. Whether the file was rewritten, one per file; nothing
        under -WhatIf, nor for a file declined at a -Confirm prompt.
    .EXAMPLE
        Update-FileToken -Path ./Program.cs -From 'OldName' -To 'NewName'

        Replaces the token in Program.cs, and returns $true if it held the
        token and $false if it did not.
    .EXAMPLE
        Get-ChildItem -File -Filter *.cs -Recurse |
            Update-FileToken -From 'OldName' -To 'NewName'

        Replaces the token in every C# file under the current folder, and
        returns one $true or $false per file.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.FileText/README.md
    .LINK
        Rename-Token
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'Its $PSCmdlet.ShouldProcess is asked by the helper it is handed to, once the file is read.')]
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
        try {
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

            $status = Edit-TextFileToken -Path $Path -From $From -To $To -Cmdlet $PSCmdlet
            if ($status -eq 'Binary') {
                Write-Warning "Skipped binary content: '$Path' holds '$From' and a NUL, so it was not rewritten."
            }

            if ($WhatIfPreference -or $status -eq 'Declined') {
                return
            }

            return $status -eq 'Edited'
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
