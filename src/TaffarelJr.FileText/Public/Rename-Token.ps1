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
        A file is read once and written back in the encoding it had, with its
        line endings untouched.
        A file that has the token but is not valid in its encoding -
        Windows-1252 text, say - is a failure, not something to rewrite: doing
        so would replace each such character for good. One without the token
        is never looked at that closely.

        Content with a NUL in it is binary - or UTF-16 or UTF-32 text without
        a byte order mark, which looks the same - and is left alone; a file
        that holds the token in such content is named in Warning. A NUL in
        the first 8 KB settles it without the file being decoded: its bytes
        are searched for the token instead.

        Symbolic links and junctions are never followed or read: a link's own
        name is renamed, but the walk does not enter a linked folder, and a
        linked file's content is left to whatever it points at. A link's
        target is never rewritten either, so a link whose target holds the
        token - one pointing at a folder of the tree that is being renamed,
        say - is named in Warning, to be re-pointed by hand. A hard link is
        an ordinary file with a second name, and is edited like any other.

        Before anything is changed, every new name is checked: one that would
        be unusable on this platform (see -To) stops the run before the
        content pass, so an unusable name cannot leave a tree whose contents
        are renamed and whose paths are not.

        -WhatIf and -Confirm name each file whose content holds the token and
        each item whose name does, one at a time; with -Confirm an item that
        is declined is left as it was and not counted.
        With -WhatIf nothing is changed and nothing is returned.

        With -Verbose, names each file as it is written and each item as it
        is renamed.
    .PARAMETER Path
        The directory tree to search, which must be a folder on the file
        system. A relative path is relative to PowerShell's current location.
        Only what is inside it is renamed: the folder's own name is left as
        it is, even when it holds the token.
    .PARAMETER From
        The token to replace.
        -WhatIf, -Confirm, -Verbose, the warnings, and the error messages
        show this text, so a secret should not be given where that output
        is kept.
    .PARAMETER To
        What to replace it with. The names it makes are judged by the file
        system this runs on, which is the one that will hold the tree: on
        Windows that refuses characters such as : and ?, a name older Windows
        and many Windows tools treat as a device (CON, NUL, COM1 ...), and
        one ending in a dot or space; elsewhere only / and NUL are refused, so
        a tree meant for Windows is best renamed there.
        -WhatIf, -Confirm, -Verbose, and the error messages show the names it
        makes, so a secret should not be given here either.
    .PARAMETER SkipExtension
        Binary-ish extensions, each with its dot, not worth reading.
        Content that turns out to be binary anyway is detected and left alone,
        so this list is a shortcut rather than the safeguard.
    .PARAMETER Exclude
        File and directory names to skip entirely, wherever they sit in the
        tree. An excluded directory is not entered at all. Empty excludes
        nothing. Each name is compared with the whole of an item's name,
        without regard to case, and literally: wildcards are not supported,
        so '*.log' excludes only an item named exactly that.
    .PARAMETER Force
        Goes ahead when -To contains -From, such as 'Foo' to 'FooBar'. That is
        refused by default because running it again would rename the result
        once more; with -Force the caller is taking that on.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. Nothing can be piped in.
    .OUTPUTS
        System.Management.Automation.PSCustomObject. FilesEdited,
        PathsRenamed, and Warning (one line per file skipped as binary,
        folder that could not be listed, or link whose target holds the
        token); nothing under -WhatIf.
    .EXAMPLE
        Rename-Token -Path ./MyProject -From 'Placeholder' -To 'MyProject'

        Replaces Placeholder in every file, file name, and folder name under
        MyProject, and throws at the end, naming each item, if any of it
        could not be done.
    .EXAMPLE
        Rename-Token -Path . -From 'Placeholder' -To 'MyProject' `
            -Exclude '.git', 'packages' -WhatIf

        Shows each file and name that would change, entering neither a
        packages folder nor a .git one, and changes nothing.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.FileText/README.md
    .LINK
        Update-FileToken
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'Its $PSCmdlet.ShouldProcess is asked by the helpers it is handed to, once each item is read.')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateScript({
                if (-not (Test-Path -LiteralPath $_ -PathType Container)) {
                    throw "'$_' is not a folder."
                }

                if ((Get-Item -LiteralPath $_ -Force).PSProvider.Name -ne 'FileSystem') {
                    throw "'$_' is not a file system path; give a folder on disk."
                }

                return $true
            })]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidatePattern('\S')]
        [string]$From,

        [Parameter(Mandatory)]
        [ValidatePattern('\S')]
        [string]$To,

        [ValidatePattern('^\.', ErrorMessage = "an extension starts with a dot, such as '.png' - not '{0}'")]
        [string[]]$SkipExtension = @(
            '.dll'
            '.exe'
            '.gif'
            '.ico'
            '.jpeg'
            '.jpg'
            '.pdf'
            '.png'
            '.snk'
            '.zip'
        ),

        [string[]]$Exclude = @(
            '.git'
            'bin'
            'node_modules'
            'obj'
        ),

        [switch]$Force
    )

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

        # Ordinal, because the replacement itself is:
        # -eq would call 'Placeholder' and 'placeholder' equal
        # and skip a rename that has real work to do.
        if ([string]::Equals($From, $To, 'Ordinal')) {
            if ($WhatIfPreference) {
                return
            }

            return [PSCustomObject]@{
                FilesEdited  = 0
                PathsRenamed = 0
                Warning      = @()
            }
        }

        $illegal = [Path]::GetInvalidFileNameChars()
        if ($To.IndexOfAny($illegal) -ge 0) {
            throw "Cannot rename '$From' to '$To': not a legal file name"
        }

        # A new name that CONTAINS the old one is not re-runnable:
        # the next run finds 'Placeholder' inside every 'PlaceholderLib' it wrote
        # last time and renames those too.
        if ($To.Contains($From) -and -not $Force) {
            throw ("Cannot rename '$From' to '$To': " +
                'the new name contains the old one, so a re-run would rename it again. ' +
                'Pass -Force to go ahead anyway.')
        }

        $candidates = Get-TokenCandidate -Path $Path -Exclude $Exclude
        if ($IsWindows) {
            $unusable = @(Find-UnusableName -Item $candidates.Item -From $From -To $To)
            if ($unusable) {
                throw ("Cannot rename '$From' to '$To': $($unusable.Count) of the new names " +
                    "would be unusable on Windows, so nothing was changed:`n  " + ($unusable -join "`n  "))
            }
        }

        $content = Update-ContentToken `
            -Item $candidates.Item `
            -From $From `
            -To $To `
            -SkipExtension $SkipExtension `
            -Cmdlet $PSCmdlet
        $names = Rename-NameToken -Item $candidates.Item -From $From -To $To -Cmdlet $PSCmdlet

        $failed = @($content.Failed) + @($names.Failed)
        if ($failed) {
            throw ("Could not rename '$From' -> '$To' in $($failed.Count) item(s):`n  " +
                ($failed -join "`n  "))
        }

        if ($WhatIfPreference) {
            return
        }

        return [PSCustomObject]@{
            FilesEdited  = $content.Edited
            PathsRenamed = $names.Renamed
            Warning      = @($candidates.Warning) + @($content.Warning)
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
