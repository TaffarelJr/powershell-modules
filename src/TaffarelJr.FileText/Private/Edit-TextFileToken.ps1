using namespace System.Diagnostics.CodeAnalysis
using namespace System.Management.Automation

function Edit-TextFileToken {
    <#
    .SYNOPSIS
        Replaces a token in one file, and says what happened.
    .DESCRIPTION
        Not exported. The file is read once and written once, in the encoding
        it was read in; its line endings survive because the whole text is
        written as it was. The caller's ShouldProcess is asked, with the
        file's full path, only once the file is known to need rewriting, so
        -WhatIf and -Confirm name only such files.
    .PARAMETER Path
        The file to edit.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with. May be empty.
    .PARAMETER Cmdlet
        The public caller's $PSCmdlet.
    .OUTPUTS
        'Edited'; 'NoToken', when the token is absent or replacing it would
        change nothing; 'Binary', when the content has a NUL and holds the
        token; or 'Declined', when ShouldProcess said no. Throws for text
        that is not valid in its encoding. When ShouldProcess cannot ask,
        because no one can answer a -Confirm prompt, its error is thrown with
        the error ID TextFileApprovalFailed, so a caller that steps over a
        file's failure can tell it apart and stop.
    #>
    [CmdletBinding()]
    [SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'Asks the public caller''s ShouldProcess, passed in as -Cmdlet.')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$From,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$To,

        [Parameter(Mandatory)]
        [PSCmdlet]$Cmdlet
    )

    $full = Resolve-TextFilePath -Path $Path -MustExist
    $edit = Get-TokenEdit -Path $full -From $From -To $To
    if ($edit.Status -ne 'Edit') {
        return $edit.Status
    }

    try {
        $approved = $Cmdlet.ShouldProcess($full, "Replace '$From'")
    }
    catch {
        throw [ErrorRecord]::new(
            $_.Exception,
            'TextFileApprovalFailed',
            [ErrorCategory]::OperationStopped,
            $full)
    }

    if (-not $approved) {
        return 'Declined'
    }

    Write-TextFile `
        -Path $full `
        -Content $edit.Content `
        -Encoding $edit.Encoding `
        -Confirm:$false
    return 'Edited'
}
