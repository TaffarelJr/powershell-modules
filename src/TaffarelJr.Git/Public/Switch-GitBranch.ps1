function Switch-GitBranch {
    <#
    .SYNOPSIS
        Checks out an existing branch, or creates a new one from a start
        point with -Create.
    .DESCRIPTION
        Without -Create, -Name must stand for a local branch. A file or
        folder of that name is never checked out in its place, so
        uncommitted work in it is never overwritten; a tag, or a branch only
        a remote has, is not switched to either. With -Create, -Name must be
        new: an existing branch is never moved, so no commit on it is left
        behind.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The branch to check out: its name, or shorthand git reads as a
        branch, such as '@{-1}' for the previous one or 'refs/heads/<name>'.
    .PARAMETER Create
        Creates the branch, at -StartPoint, and switches to it. A branch of
        that name that already exists throws: switch to it without -Create.
        Without -Create, a name that is not a local branch throws.
    .PARAMETER StartPoint
        Where a -Create'd branch starts. Defaults to HEAD. Ignored without
        -Create.
    .PARAMETER RepoPath
        The repo to switch in. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Switch-GitBranch -Name 'main'

        Checks out an existing local branch.
    .EXAMPLE
        Switch-GitBranch -Name 'feature/x' -Create -StartPoint 'origin/main'

        Creates the branch at origin/main and checks it out.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        New-GitBranch
    .LINK
        Get-GitBranch
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name,

        [switch]$Create,

        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$StartPoint,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $activity = "Switching to $Name"
        if ($Create) {
            $arguments = @('checkout', '-b', $Name)
            if ($StartPoint) {
                $arguments += $StartPoint
            }

            $arguments += '--'
            $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath
            Assert-GitNameAvailable -Kind 'branch' -Name $Name -Activity $activity `
                -Hint 'Switch to it without -Create.' -RepoPath $RepoPath
            $action = 'Create and switch to branch'
            if ($StartPoint) {
                Assert-GitRevision -Revision $StartPoint -Activity $activity -RepoPath $RepoPath
                $action += ", starting at $StartPoint"
            }

            if (-not $PSCmdlet.ShouldProcess("$root branch $Name", $action)) {
                return
            }

            Invoke-GitCommand -Activity $activity -Arguments $arguments -RepoPath $RepoPath | Out-Null
            return
        }

        $hint = 'A tag, or a branch only a remote has, is not switched to -' +
        ' pass -Create (with -StartPoint) to make a local branch.'
        $branch = Resolve-GitBranchName -Name $Name -Activity $activity -Hint $hint -RepoPath $RepoPath
        $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath
        if (-not $PSCmdlet.ShouldProcess("$root branch $branch", 'Switch to branch')) {
            return
        }

        Invoke-GitCommand -Activity $activity -Arguments @('checkout', $branch, '--') -RepoPath $RepoPath | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
