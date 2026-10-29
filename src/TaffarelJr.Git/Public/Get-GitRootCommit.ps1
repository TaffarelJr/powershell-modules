function Get-GitRootCommit {
    <#
    .SYNOPSIS
        Returns a repo's root commit SHA(s) - the history's starting
        point(s), reached by following every parent to its end.
    .DESCRIPTION
        Usually a single commit, but a history merged from unrelated
        starting points has more than one; every one of them is returned.

        A repository with no commits yet, bare or not, has no root: nothing
        is returned, and nothing is thrown. In a shallow clone, history ends
        where the clone cut it off, so the commit returned there is that
        boundary rather than the real root, and a warning says so.
    .PARAMETER Ref
        Where to start walking history backward from. Defaults to HEAD.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        The SHA of each root commit, or nothing for a repository with no
        commits.
    .EXAMPLE
        Get-GitRootCommit

        Returns the first commit of the history HEAD belongs to.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitCommit
    .LINK
        Get-GitMergeBase
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Ref = 'HEAD',

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $read = Invoke-GitCommand -Activity 'Finding the root commit' `
            -Arguments @('rev-list', '--max-parents=0', $Ref, '--') -RepoPath $RepoPath -Tolerant
        if (-not $read.Ok) {
            $inRepo = @{}
            if ($PSBoundParameters.ContainsKey('RepoPath')) {
                $inRepo.RepoPath = $RepoPath
            }

            $noCommitsYet = $Ref -ceq 'HEAD' -and (Get-GitDirectory @inRepo) -and
            -not (Resolve-GitRef -Ref 'HEAD' @inRepo)
            if ($noCommitsYet) {
                return
            }

            throw "Finding the root commit failed (exit $($read.ExitCode)): $($read.Message)"
        }

        $shallow = Invoke-GitCommand -Activity 'Checking for a shallow clone' `
            -Arguments @('rev-parse', '--is-shallow-repository') -RepoPath $RepoPath
        if (($shallow -join '').Trim() -eq 'true') {
            Write-Warning ('This is a shallow clone, so the commit returned is where its' +
                ' history was cut off, not the real root. Fetch the full history (git fetch --unshallow) first.')
        }

        return $read.Output
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
