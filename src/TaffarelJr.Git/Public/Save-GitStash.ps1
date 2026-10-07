function Save-GitStash {
    <#
    .SYNOPSIS
        Stashes uncommitted changes.
    .DESCRIPTION
        Saves the uncommitted changes of tracked files, and with
        -IncludeUntracked the untracked files too, and leaves the working
        tree clean. With nothing to stash, git succeeds without creating one.
        The result says which happened, so a later Restore-GitStash is not
        left to pop an older stash that was never meant to come back.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Message
        A label for the stash, shown by Get-GitStash.
    .PARAMETER IncludeUntracked
        Also stashes untracked files, which git otherwise leaves alone.
    .PARAMETER RepoPath
        The repo to stash in. Omit it to use the current working
        directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.Boolean
        $true when a stash was created, $false when there was nothing to stash.
    .EXAMPLE
        Save-GitStash -Message 'work in progress'

        Stashes the uncommitted changes of tracked files under a label.
    .EXAMPLE
        Save-GitStash -IncludeUntracked

        Stashes untracked files as well.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Restore-GitStash
    .LINK
        Get-GitStash
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [string]$Message,

        [switch]$IncludeUntracked,

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

        $arguments = @('stash', 'push')
        if ($IncludeUntracked) {
            $arguments += '-u'
        }

        if ($Message) {
            $arguments += @('-m', $Message)
        }

        $inRepo = @{}
        if ($PSBoundParameters.ContainsKey('RepoPath')) {
            $inRepo.RepoPath = $RepoPath
        }

        $target = Get-GitRepoLocation -Activity 'Stashing changes' -RepoPath $RepoPath
        $action = if ($IncludeUntracked) { 'Stash changes, including untracked files' } else { 'Stash changes' }
        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            return
        }

        $before = Resolve-GitRef -Ref 'refs/stash' @inRepo
        Invoke-GitCommand -Activity 'Stashing changes' -Arguments $arguments -RepoPath $RepoPath | Out-Null
        $after = Resolve-GitRef -Ref 'refs/stash' @inRepo

        return $after -ne $before
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
