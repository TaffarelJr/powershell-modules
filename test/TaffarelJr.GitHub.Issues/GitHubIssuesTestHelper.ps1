function Get-IssueTextCase {
    <#
    .SYNOPSIS
        Returns the texts every body and comment test sends, each with what
        it is a case of.
    .DESCRIPTION
        Not exported - a test-only fixture. The texts are the ones a
        transport to gh could alter: Windows line endings, a leading dash,
        characters beyond ASCII, and, with -IncludeEmpty, nothing at all.
    .PARAMETER IncludeEmpty
        Adds the empty text, for a body; gh refuses an empty comment.
    .OUTPUTS
        One hashtable per case: Text and Name.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [switch]$IncludeEmpty
    )

    @{ Text = "line 1`r`nline 2"; Name = 'Windows line endings, with no newline added' }
    @{ Text = "--- leading dashes`n-x"; Name = 'a leading dash, and line feeds left alone' }
    @{ Text = 'é ✓ 漢字'; Name = 'characters beyond ASCII' }
    if ($IncludeEmpty) {
        @{ Text = ''; Name = 'nothing at all' }
    }
}

function Get-IssueTextFile {
    <#
    .SYNOPSIS
        Returns the file a recorded gh call was given with --body-file,
        and the text it held when gh was called.
    .DESCRIPTION
        Not exported - a test-only fixture. The file is a temporary one,
        deleted once the call returns, so its text is read from the fake
        gh's record of the call.
    .PARAMETER Call
        One call, as Get-FakeGitHubCall returned it.
    .OUTPUTS
        An object with Path (the value after --body-file), Text (its text
        at call time, or $null if no file of that name was recorded), and
        FileCount (how many files the call named).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Call
    )

    $index = [array]::IndexOf($Call.Arguments, '--body-file')
    $path = $Call.Arguments[$index + 1]
    return [PSCustomObject]@{
        Path      = $path
        Text      = $Call.Files[$path]
        FileCount = $Call.Files.Count
    }
}
