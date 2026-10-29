function Get-GitConflict {
    <#
    .SYNOPSIS
        Returns every currently-conflicted path, during a merge, rebase,
        or cherry-pick.
    .DESCRIPTION
        Read from the index, NUL-separated, so a path git would otherwise
        quote and escape comes back as the name on disk. Each path is
        relative to the repository root, whichever folder this runs in, and
        comes back once. A carriage return in a path name, which only a
        file system outside Windows allows, comes back as a line feed.

        A folder that is no repository, or a repository git refuses because
        another user owns it, throws with git's message. A bare repository,
        or a .git folder itself, has no merge in progress and returns
        nothing.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        Each conflicted path, relative to the repository root.
    .EXAMPLE
        Get-GitConflict

        Lists the paths a merge, rebase or cherry-pick left conflicted.
    .EXAMPLE
        Get-GitConflict | Resolve-GitConflict -Side Ours

        Keeps the current side of every conflicted path.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Resolve-GitConflict
    .LINK
        Merge-GitBranch
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        return Get-GitUnmergedPath -Pathspec ':(top)' -Activity 'Reading conflicted paths' -RepoPath $RepoPath
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
