function Copy-GitRepository {
    <#
    .SYNOPSIS
        Clones a repository.
    .DESCRIPTION
        The new clone is never the repository that GIT_DIR, GIT_INDEX_FILE,
        GIT_WORK_TREE and the like name, so they are ignored: run from a git
        hook, a clone neither writes to the hook's index nor fails on its
        working tree.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Url
        The repository to clone.
    .PARAMETER Destination
        Where to clone it to: a folder that does not exist yet, or an empty
        one. Anything else throws before git runs. A relative path is
        resolved against PowerShell's current location.
    .PARAMETER Branch
        Checks out this branch instead of the remote's default.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Copy-GitRepository -Url 'https://github.com/OWNER/REPO.git' `
            -Destination 'C:\src\repo'

        Clones the repository into a folder that does not exist yet.
    .EXAMPLE
        Copy-GitRepository -Url 'https://github.com/OWNER/REPO.git' `
            -Destination 'C:\src\repo' -Branch 'release' -WhatIf

        Shows what would be cloned, and where, without cloning anything.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Set-GitRemote
    .LINK
        Sync-GitRemote
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Url,

        [Parameter(Mandatory, Position = 1)]
        [string]$Destination,

        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Branch
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

        $arguments = @('clone')
        if ($Branch) {
            $arguments += @('--branch', $Branch)
        }

        # After the --, nothing can be read as an option: a clone option such as
        # --upload-pack runs whatever command it is given.
        $arguments += @('--', $Url, $Destination)
        $source = Hide-UrlCredential -Text $Url
        $folder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
        $occupied = Test-Path -LiteralPath $folder -PathType Leaf
        if (Test-Path -LiteralPath $folder -PathType Container) {
            $entries = @(Get-ChildItem -LiteralPath $folder -Force)
            $occupied = $entries.Count -gt 0
        }

        if ($occupied) {
            throw "Cloning $source failed: '$folder' already exists and is not an empty folder."
        }

        $action = "Clone $source"
        if ($Branch) {
            $action += ", checking out branch $Branch"
        }

        if (-not $PSCmdlet.ShouldProcess($folder, $action)) {
            return
        }

        Invoke-GitCommand -Activity "Cloning $Url" -Arguments $arguments -NoRepository | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
