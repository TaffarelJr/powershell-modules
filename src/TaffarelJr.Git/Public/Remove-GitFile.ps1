function Remove-GitFile {
    <#
    .SYNOPSIS
        Deletes a tracked file, staging the deletion in one step.
    .DESCRIPTION
        Removes the file from the working tree and the index, as git rm
        does, so the next commit records it as deleted. A folder needs
        -Recurse, and a file with uncommitted changes needs -Force. Nothing
        asks for confirmation unless -Confirm is given.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Path
        The file or folder to delete. A bare relative path, such as
        'src/x.txt', is relative to the repository root, the way
        Get-GitStatus reports it, from whichever folder this runs in. A path
        that starts with '.' or '..', such as '.\x.txt', is relative to the
        folder this runs in (-RepoPath, else the current location), and an
        absolute path is used as it is. Each path is literal - '*', '?' and
        '[' are part of the name, not a pattern - and a backslash is read as
        a forward slash. Accepted from the pipeline, including by property
        name.
    .PARAMETER Recurse
        Required to delete a folder rather than a single file.
    .PARAMETER Force
        Deletes even a file with uncommitted changes. Without it, git
        refuses to lose that work.
    .PARAMETER RepoPath
        The repo to act in. Omit it to use the current working directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String
        A path to delete, or an object with a Path, FullName or PSPath property,
        such as the output of Get-ChildItem.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Remove-GitFile -Path 'src/obsolete.ps1'

        Deletes a tracked file and stages the deletion.
    .EXAMPLE
        Remove-GitFile -Path 'docs/old' -Recurse

        Deletes a tracked folder and everything in it, and stages the deletion.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Move-GitFile
    .LINK
        Add-GitChange
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [string[]]$Path,

        [switch]$Recurse,

        [switch]$Force,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    process {
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

            $arguments = @('rm')
            if ($Recurse) {
                $arguments += '-r'
            }

            if ($Force) {
                $arguments += '-f'
            }

            $activity = "Deleting $($Path -join ', ')"
            $arguments += '--'
            foreach ($p in $Path) {
                $arguments += ConvertTo-GitPathspec -Path $p -Activity $activity -RepoPath $RepoPath
            }

            $root = Get-GitRepoLocation -Activity $activity -RepoPath $RepoPath
            $fullPaths = foreach ($p in $Path) {
                ConvertTo-GitFullPath -Path $p -Root $root -RepoPath $RepoPath
            }

            $action = 'Delete'
            if ($Recurse) {
                $action += ', recursively'
            }

            if ($Force) {
                $action += ', even with uncommitted changes'
            }

            if (-not $PSCmdlet.ShouldProcess(($fullPaths -join ', '), $action)) {
                return
            }

            Invoke-GitCommand -Activity $activity -Arguments $arguments `
                -RepoPath $RepoPath | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
