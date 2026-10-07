function Test-GitRebaseInProgress {
    <#
    .SYNOPSIS
        Returns whether a rebase is currently under way - stopped on a
        conflict, say.
    .DESCRIPTION
        A paused 'git am' leaves a folder git's older rebase machinery
        also uses, and is not a rebase: only the marker a rebase leaves in
        it counts.

        $false for a folder that is no repository. A repository git refuses
        because another user owns it throws.
    .PARAMETER RepoPath
        The repo to check. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Boolean
        $true when a rebase is under way, $false when none is.
    .EXAMPLE
        Test-GitRebaseInProgress

        Tells whether a rebase is paused in the current repository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Start-GitRebase
    .LINK
        Resume-GitRebase
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

        $inRepo = @{}
        if ($PSBoundParameters.ContainsKey('RepoPath')) {
            $inRepo.RepoPath = $RepoPath
        }

        $gitDir = Get-GitDirectory @inRepo
        if (-not $gitDir) {
            return $false
        }

        $markers = @(
            @{
                Path = Join-Path -Path $gitDir -ChildPath 'rebase-merge'
                Type = 'Container'
            }
            @{
                Path = Join-Path -Path $gitDir -ChildPath 'rebase-apply' -AdditionalChildPath 'rebasing'
                Type = 'Leaf'
            }
        )
        foreach ($marker in $markers) {
            if (Test-Path -LiteralPath $marker.Path -PathType $marker.Type) {
                return $true
            }
        }

        return $false
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
