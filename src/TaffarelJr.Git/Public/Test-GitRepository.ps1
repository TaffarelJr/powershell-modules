function Test-GitRepository {
    <#
    .SYNOPSIS
        Returns whether a path is inside a git working tree.
    .DESCRIPTION
        $false for a bare repository, inside a repository's own .git
        folder, and for a folder that is no repository or does not exist.
        A repository git refuses to use because another user owns it (its
        safe.directory check) throws, with git's message, rather than
        reading as $false.
    .PARAMETER RepoPath
        The path to check. Omit it to check the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Boolean
        $true when the path is inside a git working tree, $false when it is not.
    .EXAMPLE
        Test-GitRepository

        Tells whether the current location is inside a git working tree.
    .EXAMPLE
        Test-GitRepository -RepoPath 'C:\src\project'

        Tells whether a folder is inside a git working tree.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitRepositoryRoot
    .LINK
        Get-GitDirectory
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $activity = 'Checking for a git repository'
        $arguments = @('rev-parse', '--is-inside-work-tree')
        $read = Invoke-GitCommand -Activity $activity -Arguments $arguments -RepoPath $RepoPath -Tolerant
        if (-not $read.Ok) {
            Assert-GitOwnershipTrusted -Activity $activity -Arguments $arguments `
                -Message $read.Message -RepoPath $RepoPath
            return $false
        }

        # A bare repository answers 'false' and still exits 0.
        return ($read.Output -join '').Trim() -eq 'true'
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
