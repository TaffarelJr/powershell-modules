using namespace System.IO

function Move-GitFile {
    <#
    .SYNOPSIS
        Renames or moves a tracked file, staging the rename in one step.
    .DESCRIPTION
        Tracked as a rename from the start, unlike a plain filesystem move
        followed by Add-GitChange - which stages a delete and an add, and
        leaves git to GUESS at the rename only when the content is similar
        enough, which it does not always get right.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Path
        The file's current path. A bare relative path, such as 'src/x.txt',
        is relative to the repository root, the way Get-GitStatus reports it,
        from whichever folder this runs in. A path that starts with '.' or
        '..', such as '.\x.txt', is relative to the folder this runs in
        (-RepoPath, else the current location), and an absolute path is used
        as it is. The path is literal - '*', '?' and '[' are part of the
        name, not a pattern - and a backslash is read as a forward slash.
    .PARAMETER Destination
        Its new path, read the same way as -Path.
    .PARAMETER Force
        Overwrites -Destination if it already exists.
    .PARAMETER RepoPath
        The repo to act in. Omit it to use the current working directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Move-GitFile -Path 'src/old.ps1' -Destination 'src/new.ps1'

        Renames a tracked file and stages the rename.
    .EXAMPLE
        Move-GitFile -Path 'src/old.ps1' -Destination 'lib/old.ps1' -Force

        Moves a tracked file, overwriting a file already at the destination.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Remove-GitFile
    .LINK
        Get-GitRename
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory, Position = 1)]
        [string]$Destination,

        [switch]$Force,

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

        $root = Get-GitRepoLocation -Activity "Renaming $Path" -RepoPath $RepoPath
        $arguments = @('mv')
        if ($Force) {
            $arguments += '-f'
        }

        # git mv takes no pathspec magic, so a bare path is made absolute against
        # the root instead; it never expands a pattern either way.
        $arguments += '--'
        foreach ($p in $Path, $Destination) {
            $full = Resolve-GitPath -Path $p -RepoPath $RepoPath
            if (-not $full) {
                $full = [Path]::Combine($root, ($p -replace '\\', '/'))
            }

            $arguments += $full -replace '\\', '/'
        }

        $source = ConvertTo-GitFullPath -Path $Path -Root $root -RepoPath $RepoPath
        $moved = ConvertTo-GitFullPath -Path $Destination -Root $root -RepoPath $RepoPath
        $action = "Move to $moved"
        if ($Force) {
            $action += ', overwriting it if it exists'
        }

        if (-not $PSCmdlet.ShouldProcess($source, $action)) {
            return
        }

        Invoke-GitCommand -Activity "Renaming $Path" -Arguments $arguments -RepoPath $RepoPath | Out-Null
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
