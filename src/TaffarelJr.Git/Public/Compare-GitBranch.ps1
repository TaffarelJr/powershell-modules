function Compare-GitBranch {
    <#
    .SYNOPSIS
        Returns how many commits a branch is ahead and behind its
        upstream, or $null when that cannot be determined.
    .DESCRIPTION
        $null covers a detached HEAD, a branch with no upstream, and a ref
        that does not exist. Anything else git cannot answer, such as a
        folder that is no repository, throws.

        A local branch, given as -Branch or -Upstream, is compared by its
        full name, so a tag that shares the name is never counted in its
        place.
    .PARAMETER Branch
        The branch to compare. Defaults to the current branch.
    .PARAMETER Upstream
        The ref to compare it against: a local branch of that name if there
        is one, else any revision, read the way git reads it. Defaults to
        -Branch's own configured upstream.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Ahead and Behind, both commit counts. Nothing is returned for a detached
        HEAD, a branch with no upstream, or a ref that does not exist.
    .EXAMPLE
        Compare-GitBranch

        Returns how far the current branch is ahead of and behind its upstream.
    .EXAMPLE
        Compare-GitBranch -Branch 'feature/x' -Upstream 'origin/main' `
            -RepoPath 'C:\src\project'

        Compares a named branch with a named ref in another repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitBranch
    .LINK
        Get-GitCherry
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Branch,

        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Upstream,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $inRepo = @{}
        if ($PSBoundParameters.ContainsKey('RepoPath')) {
            $inRepo.RepoPath = $RepoPath
        }

        $name = if ($Branch) { $Branch } else { Get-GitBranch @inRepo }
        if (-not $name) {
            return
        }

        $activity = 'Comparing branches'
        $local = Invoke-GitCommand -Activity $activity `
            -Arguments @('for-each-ref', '--format=%(refname)%00%(upstream)', "refs/heads/$name") -RepoPath $RepoPath
        $fields = @(($local -join '') -split "`0")
        $isLocal = $fields[0] -ceq "refs/heads/$name"

        $ref = if ($isLocal) { "refs/heads/$name" } else { $name }
        $upstreamRef = if ($Upstream) { $Upstream } elseif ($isLocal) { $fields[1] }
        if (-not $upstreamRef) {
            return
        }

        # The repository was read above, so show-ref's only "no" is exit 1.
        if ($Upstream) {
            $upstreamIsLocal = Invoke-GitCommand -Activity $activity `
                -Arguments @('show-ref', '--verify', '--quiet', "refs/heads/$Upstream") -RepoPath $RepoPath -Tolerant
            if ($upstreamIsLocal.Ok) {
                $upstreamRef = "refs/heads/$Upstream"
            }
        }

        $resolved = @(Resolve-GitRef -Ref $ref @inRepo) + @(Resolve-GitRef -Ref $upstreamRef @inRepo)
        if ($resolved.Count -lt 2) {
            return
        }

        $counts = Invoke-GitCommand -Activity $activity `
            -Arguments @('rev-list', '--left-right', '--count', "$ref...$upstreamRef", '--') -RepoPath $RepoPath
        $parts = ($counts -join '').Trim() -split '\s+'

        return [PSCustomObject]@{
            Ahead  = [int]$parts[0]
            Behind = [int]$parts[1]
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
