function Set-GitRemote {
    <#
    .SYNOPSIS
        Points a remote at a URL, adding it if it is new or repointing it
        if it already exists.
    .DESCRIPTION
        Adds the remote when the repository has none of that exact name,
        and otherwise changes its URL; nothing is fetched either way. A name
        git would refuse throws before anything changes.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The remote to add or repoint. Remote names are case-sensitive. A
        credential a URL given here by mistake carries is hidden in -WhatIf
        and in every message.
    .PARAMETER Url
        The URL to set it to. A credential it carries is hidden in -WhatIf,
        -Verbose and every message.
    .PARAMETER RepoPath
        The repo to set it in. Omit it to use the current working
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
        Set-GitRemote -Name 'origin' -Url 'https://github.com/OWNER/REPO.git'

        Adds the origin remote, or repoints it when it already exists.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Get-GitRemote
    .LINK
        Remove-GitRemote
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Url,

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

        $remotes = @(Invoke-GitCommand -Activity 'Listing remotes' -Arguments @('remote') -RepoPath $RepoPath)
        $shown = Hide-UrlCredential -Text $Url
        $shownName = Hide-UrlCredential -Text $Name
        if ($remotes -ccontains $Name) {
            $activity = "Repointing the $shownName remote"
            $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath -AllowBare
            if (-not $PSCmdlet.ShouldProcess("$root remote $shownName", "Set URL to $shown")) {
                return
            }

            Invoke-GitCommand -Activity $activity `
                -Arguments @('remote', 'set-url', $Name, $Url) -RepoPath $RepoPath | Out-Null
            return
        }

        $activity = "Adding the $shownName remote"
        $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath -AllowBare
        Assert-GitNameAvailable -Kind 'remote' -Name $Name -Activity $activity -MayExist -RepoPath $RepoPath
        if (-not $PSCmdlet.ShouldProcess("$root remote $shownName", "Add remote with URL $shown")) {
            return
        }

        Invoke-GitCommand -Activity $activity `
            -Arguments @('remote', 'add', $Name, $Url) -RepoPath $RepoPath | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
