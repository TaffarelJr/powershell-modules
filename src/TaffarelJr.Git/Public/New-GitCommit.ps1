function New-GitCommit {
    <#
    .SYNOPSIS
        Commits staged changes.
    .DESCRIPTION
        Records what is staged as a new commit on the current branch, or
        with -Amend folds it into the last one. No editor is opened: the
        message comes from -Message, or with -Amend -NoEdit from the commit
        being amended.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Message
        The commit message. Required unless -Amend and -NoEdit are both
        set, which keeps the amended commit's existing message.
    .PARAMETER Amend
        Folds staged changes into the previous commit instead of creating
        a new one.
    .PARAMETER AllowEmpty
        Commits even when nothing is staged. For a deliberate marker
        commit; without it, an empty commit throws.
    .PARAMETER NoEdit
        With -Amend, keeps the amended commit's message; -Message can then
        be omitted.
    .PARAMETER RepoPath
        The repo to commit in. Omit it to use the current working
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
        New-GitCommit -Message 'fix: handle an empty list'

        Commits the staged changes with a message.
    .EXAMPLE
        New-GitCommit -Amend -NoEdit

        Folds the staged changes into the last commit, keeping its message.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Add-GitChange
    .LINK
        Push-GitCommit
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [string]$Message,

        [switch]$Amend,

        [switch]$AllowEmpty,

        [switch]$NoEdit,

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

        if (-not $Message -and -not ($Amend -and $NoEdit)) {
            throw 'Committing failed: -Message is required unless both -Amend and -NoEdit are set.'
        }

        $arguments = @('commit')
        if ($Amend) {
            $arguments += '--amend'
        }

        if ($AllowEmpty) {
            $arguments += '--allow-empty'
        }

        if ($NoEdit) {
            $arguments += '--no-edit'
        }

        if ($Message) {
            $arguments += @('-m', $Message)
        }

        $target = Get-GitRepoLocation -Activity 'Committing' -RepoPath $RepoPath
        $action = 'Commit staged changes'
        if ($Amend) {
            $kept = if ($Message) { 'replacing' } else { 'keeping' }
            $action = "Amend the last commit, $kept its message"
        }

        if ($AllowEmpty) {
            $action += ', allowing an empty commit'
        }

        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            return
        }

        Invoke-GitCommand -Activity 'Committing' -Arguments $arguments -RepoPath $RepoPath | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
