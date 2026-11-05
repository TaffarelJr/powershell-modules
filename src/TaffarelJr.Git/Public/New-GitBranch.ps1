function New-GitBranch {
    <#
    .SYNOPSIS
        Creates a new branch.
    .DESCRIPTION
        Makes the branch at -StartPoint, or at HEAD, and with -Switch checks
        it out too. A name git would refuse, or one a branch already has,
        throws before anything is made.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The branch to create.
    .PARAMETER StartPoint
        Where the new branch starts. Defaults to HEAD.
    .PARAMETER Switch
        Also checks the new branch out. Without it, the branch is created
        but the current branch does not change.
    .PARAMETER RepoPath
        The repo to create it in. Omit it to use the current working
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
        New-GitBranch -Name 'feature/x'

        Creates a branch at HEAD without switching to it.
    .EXAMPLE
        New-GitBranch -Name 'hotfix/1.2' -StartPoint 'v1.2.0' -Switch

        Creates a branch at a tag and checks it out.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Switch-GitBranch
    .LINK
        Get-GitBranch
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name,

        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$StartPoint,

        [switch]$Switch,

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

        $arguments = if ($Switch) {
            @('checkout', '-b', $Name)
        }
        else {
            @('branch', $Name)
        }

        if ($StartPoint) {
            $arguments += $StartPoint
        }

        $activity = "Creating branch $Name"
        $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath -AllowBare:(-not $Switch)
        Assert-GitNameAvailable -Kind 'branch' -Name $Name -Activity $activity -RepoPath $RepoPath
        $action = if ($Switch) { 'Create and switch to branch' } else { 'Create branch' }
        if ($StartPoint) {
            Assert-GitRevision -Revision $StartPoint -Activity $activity -RepoPath $RepoPath
            $action += ", starting at $StartPoint"
        }

        if (-not $PSCmdlet.ShouldProcess("$root branch $Name", $action)) {
            return
        }

        Invoke-GitCommand -Activity $activity -Arguments $arguments -RepoPath $RepoPath | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
