using namespace System.IO

function Get-GitRepositoryRoot {
    <#
    .SYNOPSIS
        Returns a repo's top-level working directory, or $null when the
        path is not inside a git working tree.
    .DESCRIPTION
        $null also for a bare repository, which has no working tree.
        Written with the platform's own separators, where git says forward
        slashes on Windows. A repository git refuses to use because another
        user owns it (its safe.directory check) throws, with git's message,
        rather than reading as $null.
    .PARAMETER RepoPath
        The path to resolve from. Omit it to resolve from the current
        working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        The full path of the working tree's top folder, or nothing outside a
        working tree.
    .EXAMPLE
        Get-GitRepositoryRoot

        Returns the top folder of the repository the current location is in.
    .EXAMPLE
        Get-GitRepositoryRoot -RepoPath 'C:\src\project\docs'

        Finds the top folder from inside a folder of the working tree.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitDirectory
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

        $activity = 'Finding the repository root'
        $arguments = @('rev-parse', '--show-toplevel')
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
