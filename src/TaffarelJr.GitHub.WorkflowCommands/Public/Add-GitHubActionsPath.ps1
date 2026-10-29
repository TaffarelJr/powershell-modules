function Add-GitHubActionsPath {
    <#
    .SYNOPSIS
        Prepends a directory to PATH for the rest of this step and every
        step after it.
    .DESCRIPTION
        Also prepends it to this process's own PATH immediately, since
        the file this writes to only takes effect for steps that start
        after the current one ends.

        The directory is written as a full path: a relative one would
        mean a different place to every later step that started
        somewhere else. A path holding a line break throws, as it would
        add a second entry of its own to the file, and so does one
        holding the path separator, which PATH would read as two folders.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Path
        The directory to add. A relative path is taken from the current
        location, which must then be a file-system one. A path PowerShell
        cannot resolve, such as one on a drive that does not exist, throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String. The directory to add.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Add-GitHubActionsPath -Path './tools/bin'

        Puts the folder, as a full path, at the front of PATH for the rest
        of this step and every step after it.
    .EXAMPLE
        './tools/bin', './tools/scripts' | Add-GitHubActionsPath

        Adds each piped folder as a call of its own would.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidatePattern(
            '^[^\r\n]*\S[^\r\n]*\z',
            ErrorMessage = "'{0}' is not a path the path file can hold: it must not be blank or contain a line break.")]
        [string]$Path
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

            $file = Resolve-GitHubActionsFilePath -Variable 'GITHUB_PATH'
            $shownPath = Hide-UrlCredential -Text $Path
            $directory = Resolve-GitHubActionsFileSystemPath -Path $Path -Subject "-Path is '$shownPath'" -Kind 'folder'
            $shownDirectory = Hide-UrlCredential -Text $directory
            $separator = [System.IO.Path]::PathSeparator
            if ($directory.Contains($separator)) {
                throw ("'$shownDirectory' holds the path separator '$separator', " +
                    'so PATH would read it as more than one folder; ' +
                    'add each folder with a call of its own.')
            }

            if (-not $PSCmdlet.ShouldProcess($shownDirectory, 'Add to PATH')) {
                return
            }

            Add-GitHubActionsFileText -Variable 'GITHUB_PATH' -Path $file -Text "$directory`n"
            $env:PATH = $directory + $separator + $env:PATH
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
