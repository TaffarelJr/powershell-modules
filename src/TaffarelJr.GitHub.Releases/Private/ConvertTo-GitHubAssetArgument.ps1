using namespace System.IO

function ConvertTo-GitHubAssetArgument {
    <#
    .SYNOPSIS
        Returns the argument that makes gh upload one file exactly as
        named, never as a wildcard pattern.
    .DESCRIPTION
        gh reads an asset argument as a wildcard pattern, so a file named
        a[1].zip is not found, unless the argument holds a #: then the text
        before the first # is the file, taken literally, and the rest its
        display label. So the file's resolved path is sent with a bare #
        on the end, which gives no label.

        A # inside the path itself would cut the path short, so such a path
        is sent relative to the current location instead - gh starts there
        - when that relative form holds no #; otherwise it throws, naming
        the file.
    .PARAMETER LiteralPath
        The file, as the caller gave it: relative to PowerShell's location,
        ~, or on a drive.
    .PARAMETER Name
        The caller's parameter the file came from, without its dash, for a
        message.
    .OUTPUTS
        The argument for gh.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath,

        [Parameter(Mandatory)]
        [ValidatePattern('^\w+\z', ErrorMessage = "'{0}' is not a parameter name: give it without its dash.")]
        [string]$Name
    )

    $full = Resolve-GitHubInputFile -Path $LiteralPath -Name $Name
    if (-not $full.Contains('#')) {
        return "$full#"
    }

    $location = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
    $relative = [Path]::GetRelativePath($location, $full)
    if (-not $relative.Contains('#')) {
        return "$relative#"
    }

    $shown = Hide-UrlCredential -Text $full
    throw "-$Name '$shown' holds a '#', which gh reads as the start of a label, and so does its path from" +
    " the current location. Rename or copy the file, or run from inside the folder whose name holds the '#'."
}
