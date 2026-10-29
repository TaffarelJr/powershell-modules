function Get-GitDiff {
    <#
    .SYNOPSIS
        Returns a diff, as patch text by default or a path listing with
        -NameOnly/-NameStatus.
    .DESCRIPTION
        Plain, uncolored output whatever the user's config says: a
        color.ui of 'always', an external diff tool, or a textconv driver
        named in .gitattributes would otherwise end up in the text, or start
        a program of the config's choosing. The header lines name the two
        sides a/ and b/, whatever diff.mnemonicPrefix or diff.noprefix say.
        In a path listing, a path with non-ASCII characters is written as it
        is on disk, not as git's escaped octal.

        A ref named like a file or folder is still read as a ref.
    .PARAMETER FromRef
        The earlier side of the comparison. Omit both -FromRef and -ToRef
        to compare the working tree against the index, which shows the
        unstaged changes, or the index against HEAD with -Staged.
    .PARAMETER ToRef
        The later side of the comparison. Given without -FromRef, it is
        compared against the working tree (or the index, with -Staged), and
        is then the earlier side.
    .PARAMETER Staged
        Compares the index instead of the working tree.
    .PARAMETER Path
        Scopes the diff to one path. A bare relative path, such as
        'src/x.txt', is relative to the repository root, from whichever
        folder this runs in. A path that starts with '.' or '..', such as
        '.\x.txt', is relative to the folder this runs in (-RepoPath, else
        the current location), and an absolute path is used as it is. The
        path is literal - '*', '?' and '[' are part of the name, not a
        pattern - and a backslash is read as a forward slash.
    .PARAMETER NameOnly
        Returns just the changed paths, one per line.
    .PARAMETER NameStatus
        Returns each changed path with its status letter (A/M/D/R/...).
        Cannot be combined with -NameOnly.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        The diff as patch text, one line at a time; with -NameOnly or
        -NameStatus, a listing of the changed paths.
    .EXAMPLE
        Get-GitDiff -Staged

        Returns the patch for the changes staged for the next commit.
    .EXAMPLE
        Get-GitDiff -FromRef 'main' -ToRef 'HEAD' -NameStatus

        Lists each path that differs between main and HEAD, with its status.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitStatus
    .LINK
        Get-GitLog
    #>
    [CmdletBinding(DefaultParameterSetName = 'Patch')]
    [OutputType([string])]
    param(
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$FromRef,

        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$ToRef,

        [switch]$Staged,

        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'NameOnly')]
        [switch]$NameOnly,

        [Parameter(Mandatory, ParameterSetName = 'NameStatus')]
        [switch]$NameStatus,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $arguments = @(
            '-c', 'core.quotePath=false', 'diff', '--no-color', '--no-ext-diff', '--no-textconv',
            '--src-prefix=a/', '--dst-prefix=b/'
        )
        if ($Staged) {
            $arguments += '--cached'
        }

        if ($NameOnly) {
            $arguments += '--name-only'
        }
        elseif ($NameStatus) {
            $arguments += '--name-status'
        }

        if ($FromRef) {
            $arguments += $FromRef
        }

        if ($ToRef) {
            $arguments += $ToRef
        }

        $arguments += '--'
        if ($Path) {
            $arguments += ConvertTo-GitPathspec -Path $Path -Activity 'Reading the diff' -RepoPath $RepoPath
        }

        return Invoke-GitCommand -Activity 'Reading the diff' -Arguments $arguments -RepoPath $RepoPath
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
