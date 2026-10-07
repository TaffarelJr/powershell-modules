function Test-GitChange {
    <#
    .SYNOPSIS
        Returns whether something changed - staged changes by default, or
        a path's difference between two refs.
    .DESCRIPTION
        Throws for a ref that does not exist: only a clean answer is
        $true or $false, never an error read as "changed". Checking staged
        changes needs a working tree, and comparing refs a repository; a
        folder that has neither throws saying so, rather than leaving git to
        compare two files of those names outside any repository.
    .PARAMETER FromRef
        The earlier ref to compare. Requires -ToRef.
    .PARAMETER ToRef
        The later ref to compare. Requires -FromRef.
    .PARAMETER Staged
        Checks staged changes instead of a ref range. This is already the
        default when neither -FromRef nor -ToRef is given, so -Staged:$false
        is refused rather than read as a request for something else.
    .PARAMETER Path
        Scopes the check to one path. A bare relative path, such as
        'src/x.txt', is relative to the repository root, from whichever
        folder this runs in. A path that starts with '.' or '..', such as
        '.\x.txt', is relative to the folder this runs in (-RepoPath, else
        the current location), and an absolute path is used as it is. The
        path is literal - '*', '?' and '[' are part of the name, not a
        pattern - and a backslash is read as a forward slash. Omit it to
        check the whole tree.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Boolean
        $true when there is a difference, $false when there is none.
    .EXAMPLE
        Test-GitChange

        Tells whether anything is staged.
    .EXAMPLE
        Test-GitChange -FromRef 'v1.0.0' -ToRef 'HEAD' -Path 'docs'

        Tells whether anything under docs changed between a tag and HEAD.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitDiff
    .LINK
        Get-GitStatus
    #>
    [CmdletBinding(DefaultParameterSetName = 'Staged')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Range')]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$FromRef,

        [Parameter(Mandatory, ParameterSetName = 'Range')]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$ToRef,

        [Parameter(ParameterSetName = 'Staged')]
        [switch]$Staged,

        [string]$Path,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        if ($PSBoundParameters.ContainsKey('Staged') -and -not $Staged) {
            throw 'Checking for changes failed: -Staged:$false is not supported - staged changes are the default;' +
            ' pass -FromRef and -ToRef to compare two refs.'
        }

        $inRepo = @{}
        if ($PSBoundParameters.ContainsKey('RepoPath')) {
            $inRepo.RepoPath = $RepoPath
        }

        $where = if ($RepoPath) { "'$RepoPath'" } else { 'the current folder' }
        $arguments = @('diff', '--quiet')
        if ($PSCmdlet.ParameterSetName -eq 'Staged') {
            if (-not (Test-GitRepository @inRepo)) {
                throw "Checking for changes failed: $where is not inside a git working tree," +
                ' so nothing can be staged there.'
            }

            $arguments += '--cached'
        }
        else {
            if (-not (Get-GitDirectory @inRepo)) {
                throw "Checking for changes failed: $where is not inside a git repository."
            }

            $arguments += @($FromRef, $ToRef)
        }

        $arguments += '--'
        if ($Path) {
            $arguments += ConvertTo-GitPathspec -Path $Path -Activity 'Checking for changes' -RepoPath $RepoPath
        }

        $read = Invoke-GitCommand -Activity 'Checking for changes' -Arguments $arguments -RepoPath $RepoPath -Tolerant

        # 0 is no difference and 1 is a difference; anything else is git failing
        # to answer.
        if ($read.ExitCode -gt 1) {
            throw "Checking for changes failed (exit $($read.ExitCode)): $($read.Message)"
        }

        return -not $read.Ok
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
