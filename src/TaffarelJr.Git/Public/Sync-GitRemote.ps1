function Sync-GitRemote {
    <#
    .SYNOPSIS
        Fetches from a remote.
    .DESCRIPTION
        Updates the remote-tracking branches, and with -Tags the tags, from
        one remote or from every one; the local branches and the working
        tree are left as they are.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The remote to fetch. Defaults to 'origin'. Also accepted as -Remote.
    .PARAMETER Refspec
        A specific branch or refspec to fetch, instead of the remote's
        usual set. Cannot be combined with -All.
    .PARAMETER Prune
        Removes local remote-tracking refs whose branch no longer exists
        on the remote.
    .PARAMETER Tags
        Also fetches every tag.
    .PARAMETER All
        Fetches every configured remote instead of just one.
    .PARAMETER RepoPath
        The repo to fetch into. Omit it to use the current working
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
        Sync-GitRemote -Prune

        Fetches origin and removes remote-tracking refs for deleted branches.
    .EXAMPLE
        Sync-GitRemote -All -Tags

        Fetches every configured remote, with every tag.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Update-GitBranch
    .LINK
        Push-GitCommit
    #>
    [CmdletBinding(DefaultParameterSetName = 'Remote', SupportsShouldProcess)]
    param(
        [Parameter(ParameterSetName = 'Remote')]
        [Alias('Remote')]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name = 'origin',

        [Parameter(ParameterSetName = 'Remote')]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Refspec,

        [switch]$Prune,

        [switch]$Tags,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,

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

        $arguments = @('fetch')
        if ($All) {
            $arguments += '--all'
        }

        if ($Prune) {
            $arguments += '--prune'
        }

        if ($Tags) {
            $arguments += '--tags'
        }

        $root = Get-GitRepoLocation -Activity 'Fetching' -RepoPath $RepoPath -AllowBare
        $target = $root
        $action = 'Fetch every remote'
        if (-not $All) {
            $arguments += $Name
            Assert-GitRemoteSource -Name $Name -Activity 'Fetching' -RepoPath $RepoPath
            $remote = Hide-UrlCredential -Text $Name
            $target = "$root remote $remote"
            $action = 'Fetch'
            if ($Refspec) {
                $arguments += $Refspec
                $action += " $Refspec"
            }

            if ($Refspec.StartsWith('+')) {
                $action += ', allowing a forced update'
            }
        }

        if ($Prune) {
            $action += ', pruning stale remote-tracking refs'
        }

        if ($Tags) {
            $action += ', with every tag'
        }

        if (-not $PSCmdlet.ShouldProcess($target, $action)) {
            return
        }

        Invoke-GitCommand -Activity 'Fetching' -Arguments $arguments -RepoPath $RepoPath | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
