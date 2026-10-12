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
        file reads the same on every platform. Settings are single-line JSON
        values, one per setting.

        The file takes the encoding and line ending it already has when
        overwritten with -Force, and otherwise this platform's own. Throws
        if the file exists and -Force is not given, if its folder does not
        exist, or if a workspace folder does not exist.
    .PARAMETER Path
        The workspace file to write. It has to end in .code-workspace, which
        is how VS Code recognizes one, and its own folder has to exist.
    .PARAMETER Folder
        The folders to include, in order - the first is the primary one.
        Each is a path; a dictionary or object with Path and optionally
        Name (a display name) and Comment (written above the entry); or a
        DirectoryInfo, so Get-ChildItem -Directory pipes straight in.
        Relative paths resolve against the current location.
    .PARAMETER Settings
        Workspace settings, keyed by setting name. Don't repeat a key that
        -MirrorSettingsFrom also supplies.
    .PARAMETER Extension
        Extension ids, in publisher.name form, to recommend when the
        workspace is opened.
    .PARAMETER Comment
        Lines written as comments at the top of the file, one per element.
    .PARAMETER MirrorSettingsFrom
        A folder whose .vscode/settings.json is copied in, comments and key
        order intact, after -Settings. VS Code ignores window-scoped
        settings from a folder while a multi-root workspace is open, so
        they only take effect when restated here. A folder without that
        file contributes nothing.
    .PARAMETER Force
        Overwrites an existing workspace file instead of throwing.
    .OUTPUTS
        The workspace file's full path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('\.code-workspace$')]
        [string]$Path,

        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$Folder,

        [System.Collections.IDictionary]$Settings,

        [string[]]$Extension,

        [string[]]$Comment,

        [string]$MirrorSettingsFrom,

        [switch]$Force
    )

    begin {
        $folders = [List[object]]::new()
    }

    process {
        $folders.AddRange($Folder)
    }

    end {
        $filePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $directory = [Path]::GetDirectoryName($filePath)
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            throw "The workspace file's folder does not exist: $directory"
        }

        if ((Test-Path -LiteralPath $filePath) -and -not $Force) {
            throw "The workspace file already exists (use -Force to overwrite it): $filePath"
        }

        $specs = foreach ($item in $folders) {
            ConvertTo-WorkspaceFolderSpec -Folder $item
        }

        $content = @{
            Directory = $directory
            Folder    = $specs
        }

        if ($PSBoundParameters.ContainsKey('Settings')) {
            $content['Settings'] = $Settings
        }

        if ($PSBoundParameters.ContainsKey('Extension')) {
            $content['Extension'] = $Extension
        }

        if ($PSBoundParameters.ContainsKey('Comment')) {
            $content['Comment'] = $Comment
        }

        if ($MirrorSettingsFrom) {
            $content['MirrorFolderPath'] = Get-NativePath -Path $MirrorSettingsFrom
        }

        $lines = Get-WorkspaceContent @content
        Write-TextFile -Path $filePath -Lines $lines
        return $filePath
    }
}
