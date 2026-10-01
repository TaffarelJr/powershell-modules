using namespace System.IO

function Rename-Token {
    <#
    .SYNOPSIS
        Replaces a placeholder token in file content,
        file names, and directory names.
    .DESCRIPTION
        Two passes, in this order:
        file contents, then names longest-path-first.
        Contents first because the item list is a snapshot taken up front,
        and a rename would stale the path of any file not yet read.
        Names longest-path-first for the same reason in miniature:
        renaming a parent would stale every path beneath it.

        Neither pass stops at its first failure.
        The token has already been replaced elsewhere by then,
        and a tree that is half one name and half the other
        is easier to reason about with every gap named at once
        than with only the first.
        So each pass collects what it could not do,
        and this throws at the end if anything is on that list -
        a caller must never land a commit on a tree that still says both names.

        Case-sensitive throughout, so a token differing from its replacement
        only in case is still a rename.
        Content is read and written through Read-TextFile/Write-TextFile,
        so a file's encoding and line ending survive the rewrite.
    .PARAMETER Path
        The directory tree to search.
    .PARAMETER From
        The token to replace.
    .PARAMETER To
        What to replace it with.
    .PARAMETER SkipExtension
        Binary-ish extensions not worth reading.
        Content that turns out to be binary anyway is detected and left alone,
        so this list is a shortcut rather than the safeguard.
    .PARAMETER Exclude
        Directory names to skip entirely.
    .OUTPUTS
        A pscustomobject with FilesEdited, PathsRenamed, and Warning
        (one line per file skipped as binary
        or subtree that could not be listed).
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container },
            ErrorMessage = "no such folder '{0}'")]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidatePattern('\S')]
        [string]$From,

        [Parameter(Mandatory)]
        [ValidatePattern('\S')]
        [string]$To,

        [string[]]$SkipExtension = @(
            '.png', '.jpg', '.jpeg', '.gif', '.ico', '.svg',
            '.pdf', '.zip', '.dll', '.exe', '.snk'
        ),

        [string[]]$Exclude = @('.git', 'bin', 'obj', 'node_modules')
    )

    # Ordinal, because the replacement itself is:
    # -eq would call 'Placeholder' and 'placeholder' equal
    # and skip a rename that has real work to do.
    if ([string]::Equals($From, $To, 'Ordinal')) {
        return [PSCustomObject]@{
            FilesEdited  = 0
            PathsRenamed = 0
            Warning      = @()
        }
    }

    # Both checked before the content pass mutates anything,
    # so an unusable name cannot leave a tree whose contents are renamed
    # and whose paths are not.
    $illegal = [Path]::GetInvalidFileNameChars()
    if ($To.IndexOfAny($illegal) -ge 0) {
        throw "Cannot rename '$From' to '$To': not a legal file name"
    }

    # A new name that CONTAINS the old one is not re-runnable:
    # the next run finds 'Placeholder' inside every 'PlaceholderLib' it wrote
    # last time and renames those too.
    if ($To.Contains($From)) {
        throw ("Cannot rename '$From' to '$To': the new name contains the old " +
            'one, so a re-run would rename it again')
    }

    $candidates = Get-TokenCandidate -Path $Path -Exclude $Exclude
    $content = Update-ContentToken -Item $candidates.Item -From $From -To $To -SkipExtension $SkipExtension
    $names = Rename-NameToken -Item $candidates.Item -From $From -To $To

    $failed = @($content.Failed) + @($names.Failed)
    if ($failed) {
        throw ("Could not rename '$From' -> '$To' in $($failed.Count) item(s):`n  " +
            ($failed -join "`n  "))
    }

    return [PSCustomObject]@{
        FilesEdited  = $content.Edited
        PathsRenamed = $names.Renamed
        Warning      = @($candidates.Warning) + @($content.Warning)
    }
}
