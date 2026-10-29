function Get-GitDefaultBranch {
    <#
    .SYNOPSIS
        Returns a remote's default branch name, or $null when the remote
        has none.
    .DESCRIPTION
        Reads the remote's own HEAD symlink rather than assuming 'main' or
        'master', so a caller never has to hard-code either. That ref is
        set by a fresh clone, but a shallow or partial fetch of just one
        branch may not have it - this falls back to asking the remote
        directly (git ls-remote --symref) when it is missing, at the cost
        of that one call reaching the network. That answer is in a format
        git does not translate, so it reads the same in any language.

        $null means the remote answered but has no HEAD to name. A remote
        that cannot be asked - one that does not exist, a bad name, a
        network or sign-in failure - throws with git's reason, and so does a
        folder that is no repository, or one git refuses because another
        user owns it.
    .PARAMETER Name
        The remote to ask. Defaults to 'origin'. Also accepted as -Remote.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        The remote's default branch name, or nothing when the remote has none.
    .EXAMPLE
        Get-GitDefaultBranch

        Returns the default branch of origin, such as main.
    .EXAMPLE
        Get-GitDefaultBranch -Name 'upstream' -RepoPath 'C:\src\project'

        Returns the default branch of another remote of another repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitRemote
    .LINK
        Get-GitBranch
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Alias('Remote')]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name = 'origin',

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $activity = 'Reading the default branch'
        $read = Invoke-GitCommand -Activity $activity `
            -Arguments @('symbolic-ref', '--quiet', "refs/remotes/$Name/HEAD") -RepoPath $RepoPath -Tolerant

        # 1 is a ref that is missing or not symbolic; anything else is git
        # failing to answer.
        if ($read.ExitCode -gt 1) {
            throw "$activity failed (exit $($read.ExitCode)): $($read.Message)"
        }

        if ($read.Ok) {
            $ref = ($read.Output -join '').Trim()
            $prefix = "refs/remotes/$Name/"
            if ($ref.StartsWith($prefix)) {
                return $ref.Substring($prefix.Length)
            }
        }

        $asking = "Asking $Name for its default branch"
        $remote = Invoke-GitCommand -Activity $asking `
            -Arguments @('ls-remote', '--symref', $Name, 'HEAD') -RepoPath $RepoPath -Tolerant
        if (-not $remote.Ok) {
            throw "$(Hide-UrlCredential -Text $asking) failed (exit $($remote.ExitCode)): $($remote.Message)"
        }

        # A remote whose own HEAD was never pointed at a branch (common for a
        # freshly-created bare repo) prints no 'ref:' line at all.
        foreach ($line in $remote.Output) {
            if ($line -match '^ref:\s*refs/heads/(\S+)\s+HEAD$') {
                return $Matches[1]
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
