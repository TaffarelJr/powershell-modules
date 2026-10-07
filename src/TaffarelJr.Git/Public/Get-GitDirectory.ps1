using namespace System.IO

function Get-GitDirectory {
    <#
    .SYNOPSIS
        Returns a repo's absolute .git directory, or $null when the path
        is not inside a git repository.
    .DESCRIPTION
        Asked of git rather than assumed to be '<root>/.git' - a worktree
        or submodule's git directory is a FILE pointing elsewhere, not a
        folder at that path. Written with the platform's own separators,
        where git says forward slashes on Windows. A repository git refuses
        to use because another user owns it (its safe.directory check)
        throws, with git's message, rather than reading as $null.
    .PARAMETER RepoPath
        The path to resolve from. Omit it to resolve from the current
        working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        The full path of the git directory, or nothing outside a repository.
    .EXAMPLE
        Get-GitDirectory

        Returns the path of the .git folder of the current repository.
    .EXAMPLE
        Get-GitDirectory -RepoPath 'C:\src\project\docs'

        Finds the git directory from inside a folder of the working tree.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitRepositoryRoot
    .LINK
        Test-GitRepository
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

        $activity = 'Finding the git directory'
        $arguments = @('rev-parse', '--absolute-git-dir')
        $read = Invoke-GitCommand -Activity $activity -Arguments $arguments -RepoPath $RepoPath -Tolerant
        if (-not $read.Ok) {
            Assert-GitOwnershipTrusted -Activity $activity -Arguments $arguments `
                -Message $read.Message -RepoPath $RepoPath
            return
        }

        return [Path]::GetFullPath(($read.Output -join '').Trim())
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
