using namespace System.IO
using namespace System.Text

function Use-GitHubTextFile {
    <#
    .SYNOPSIS
        Writes text to a temporary file, runs a script block with the
        file's path, and deletes the file afterwards.
    .DESCRIPTION
        For a body gh is to read from a file - --body-file, --notes-file,
        or gh api's --input - so it arrives exactly as given. Piped on
        standard input, the same text would gain a trailing newline.

        The file holds the text and nothing else: UTF-8 with no byte-order
        mark, no newline added, line endings as they are. An empty string
        gives an empty file. The file is deleted however the block ends,
        a throw included. On Linux and macOS it is created readable and
        writable by its owner alone, so another user of the machine never
        sees the text.
    .PARAMETER Text
        The text to write.
    .PARAMETER ScriptBlock
        Run with the file's full path as its first argument, so it can
        take it as param($Path).
    .INPUTS
        None
    .OUTPUTS
        System.Object
        Whatever the script block outputs.
    .EXAMPLE
        Use-GitHubTextFile -Text $Body -ScriptBlock {
            param($file)
            $arguments = @('issue', 'comment', '7', '--body-file', $file)
            Invoke-GitHubCommand -Activity 'Commenting' -Argument $arguments
        }

        Posts a comment whose text reaches gh byte for byte.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $path = Join-Path ([Path]::GetTempPath()) "gh-text-$([Guid]::NewGuid()).txt"
        $options = [FileStreamOptions]@{
            Mode   = [FileMode]::CreateNew
            Access = [FileAccess]::Write
            Share  = [FileShare]::None
        }
        if (-not $IsWindows) {
            # Owner-only from the moment it exists: the temp folder is shared, and the body may be private.
            $options.UnixCreateMode = [UnixFileMode]'UserRead, UserWrite'
        }

        try {
            $writer = [StreamWriter]::new($path, [UTF8Encoding]::new($false), $options)
            try {
                $writer.Write($Text)
            }
            finally {
                $writer.Dispose()
            }

            & $ScriptBlock $path
        }
        finally {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Force
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
