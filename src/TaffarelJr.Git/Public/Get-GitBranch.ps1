function Get-GitBranch {
    <#
    .SYNOPSIS
        Returns the current branch name, or every local branch with -List.
    .DESCRIPTION
        The current branch is $null on a detached HEAD, where there is none.
        A repository that has no commits yet still has a current branch.
        Anything else git cannot answer - a folder that is no repository, or
        one git refuses because another user owns it - throws, with git's
        message, rather than reading as a detached HEAD.

        Names are read from the full ref and stripped of 'refs/heads/'
        rather than asked of git in short form, which writes 'heads/main'
        for a branch whose name a tag also has.
    .PARAMETER List
        Returns every local branch name instead of just the current one.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        The current branch's name, or nothing on a detached HEAD; with -List,
        the name of every local branch.
    .EXAMPLE
        Get-GitBranch

        Returns the name of the current branch.
    .EXAMPLE
        Get-GitBranch -List -RepoPath 'C:\src\project'

        Returns the name of every local branch of another repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        New-GitBranch
    .LINK
        Switch-GitBranch
    .LINK
        Remove-GitBranch
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [switch]$List,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $prefix = 'refs/heads/'

        if ($List) {
            $refs = Invoke-GitCommand -Activity 'Listing branches' `
                -Arguments @('for-each-ref', '--format=%(refname)', $prefix) -RepoPath $RepoPath
            foreach ($ref in $refs) {
                $ref.Substring($prefix.Length)
            }

            return
        }

        $read = Invoke-GitCommand -Activity 'Reading the current branch' `
            -Arguments @('symbolic-ref', '--quiet', 'HEAD') -RepoPath $RepoPath -Tolerant

        # 1 is a detached HEAD; anything else is git failing to answer.
        if ($read.ExitCode -eq 1) {
            return
        }

        if (-not $read.Ok) {
            throw "Reading the current branch failed (exit $($read.ExitCode)): $($read.Message)"
        }

        $ref = ($read.Output -join '').Trim()
        if ($ref.StartsWith($prefix)) {
            return $ref.Substring($prefix.Length)
        }

        return $ref
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
