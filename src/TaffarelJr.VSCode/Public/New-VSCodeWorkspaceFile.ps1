using namespace System.Collections.Generic
using namespace System.IO

function New-VSCodeWorkspaceFile {
    <#
    .SYNOPSIS
        Writes a multi-root .code-workspace file and returns its path.
    .DESCRIPTION
        Written as JSONC, with comments where asked for, which VS Code reads
        as it does its own settings files. Folder paths are stored relative
        to the workspace file's own folder, forward slashes only, so the
        file reads the same on every platform - unless a folder is on
        another drive or share, which can only be written as an absolute
        path. Settings are single-line JSON values, one per setting.

        The file takes the encoding and line ending it already has when
        overwritten with -Force, and otherwise UTF-8 without a byte order
        mark and this platform's own line ending. Nothing is written - and
        an existing file is left as it was - if anything is refused:
        the file exists and -Force is not given, its folder does not exist,
        a workspace folder does not exist or is given twice, or a setting
        cannot be written as JSON. A refusal is a terminating error for the
        call, and in a pipeline it stops the pipeline.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Path
        The workspace file to write. It has to end in .code-workspace, which
        is how VS Code recognizes one, and its own folder has to exist.
    .PARAMETER Folder
        The folders to include, in order - the first is the primary one.
        Each is a path; a dictionary or object with Path and optionally
        Name (a display name) and Comment (written above the entry); or a
        DirectoryInfo, so Get-ChildItem -Directory pipes straight in.
        Relative paths resolve against the current location. Each has to
        be an existing folder, given once.
    .PARAMETER Setting
        Workspace settings, keyed by setting name. Each value has to be
        something JSON can hold: a string, finite number, boolean, $null,
        list, dictionary, or custom object - so values read with
        ConvertFrom-Json qualify; read a whole settings file with
        ConvertFrom-Json -AsHashtable to pass it in. Pass an [ordered]
        dictionary to control key order.
        A key that -MirrorSettingsFrom also supplies is refused.
        Also accepted as -Settings.
    .PARAMETER Extension
        Extension ids, in publisher.name form, to recommend when the
        workspace is opened. An id given again in other casing is written
        once.
    .PARAMETER Comment
        Lines written as comments at the top of the file, one per element;
        an element holding line breaks becomes one comment line per line.
    .PARAMETER MirrorSettingsFrom
        A folder whose .vscode/settings.json is copied in, comments and key
        order intact, after -Setting. VS Code ignores window-scoped
        settings from a folder while a multi-root workspace is open, so
        they only take effect when restated here. Everything in the file is
        copied, and workspace settings apply to every folder of the
        workspace: a setting meant for this one folder reaches the others
        too, wherever they do not set it themselves. A folder without that
        file, or whose file is empty, contributes nothing; a file that
        PowerShell's JSON reader cannot parse, or that holds no object, is
        refused. Looseness the reader accepts but VS Code itself flags, such
        as unquoted keys or single-quoted strings, is copied as written.
    .PARAMETER Force
        Overwrites an existing workspace file instead of throwing.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object. A folder, as a path; or an object with a Path and
        optionally a Name and a Comment, such as the directories
        Get-ChildItem -Directory returns.
    .OUTPUTS
        System.String. The workspace file's full path; nothing under -WhatIf.
    .EXAMPLE
        New-VSCodeWorkspaceFile -Path ./app/app.code-workspace -Folder ./app

        Writes a workspace holding one folder, and returns the path of the
        file.
    .EXAMPLE
        New-VSCodeWorkspaceFile -Path ./app/app.code-workspace `
            -Folder ./app, ./shared-lib -MirrorSettingsFrom ./app `
            -Setting ([ordered]@{ 'editor.rulers' = @(80, 120) })

        Writes a workspace with app as its primary folder, restating app's
        own settings for the whole workspace.
    .EXAMPLE
        Get-ChildItem -Path ./repos -Directory |
            New-VSCodeWorkspaceFile -Path ./repos/repos.code-workspace

        Writes a workspace with every repository folder in it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.VSCode/README.md
    .LINK
        Start-VSCode
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('\.code-workspace\z')]
        [string]$Path,

        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Folder,

        [Alias('Settings')]
        [System.Collections.IDictionary]$Setting,

        [ValidatePattern('^[A-Za-z0-9][\w-]*\.[A-Za-z0-9][\w.-]*\z')]
        [string[]]$Extension,

        [string[]]$Comment,

        [string]$MirrorSettingsFrom,

        [switch]$Force
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            $folders = [List[object]]::new()
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            foreach ($item in $Folder) {
                $folders.Add($item)
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    end {
        try {
            $filePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            $directory = [Path]::GetDirectoryName($filePath)
            if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
                throw "The workspace file's folder does not exist: $directory"
            }

            if ((Test-Path -LiteralPath $filePath) -and -not $Force) {
                throw "The workspace file already exists (use -Force to overwrite it): $filePath"
            }

            if ($folders.Count -eq 0) {
                throw 'No workspace folder was given.'
            }

            $specs = foreach ($item in $folders) {
                ConvertTo-WorkspaceFolderSpec -Folder $item
            }

            $content = @{
                Directory = $directory
                Folder    = $specs
            }

            if ($PSBoundParameters.ContainsKey('Setting')) {
                $content['Settings'] = $Setting
            }

            if ($PSBoundParameters.ContainsKey('Extension')) {
                $content['Extension'] = $Extension
            }

            if ($PSBoundParameters.ContainsKey('Comment')) {
                $content['Comment'] = $Comment
            }

            if ($MirrorSettingsFrom) {
                if (-not (Test-Path -LiteralPath $MirrorSettingsFrom -PathType Container)) {
                    throw "-MirrorSettingsFrom is not a folder: $MirrorSettingsFrom"
                }

                $content['MirrorFolderPath'] = Get-NativePath -Path $MirrorSettingsFrom
            }

            $lines = @(Get-WorkspaceContent @content)
            if (-not $PSCmdlet.ShouldProcess($filePath, 'Write workspace file')) {
                return
            }

            try {
                # Another module's function follows the session's -WhatIf and
                # -Confirm, not this call's, so it is told the answer given above.
                Write-TextFile -Path $filePath -Line $lines -WhatIf:$false -Confirm:$false
            }
            catch {
                $reason = $_.Exception.GetBaseException().Message
                throw "Could not write the workspace file $filePath ($reason)"
            }

            return $filePath
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
