function Resolve-GitHubActionsFileSystemPath {
    <#
    .SYNOPSIS
        Returns the full file-system path a PowerShell path names, without
        requiring it to exist.
    .DESCRIPTION
        Not exported. Shared by Resolve-GitHubActionsFilePath and
        Add-GitHubActionsPath. A relative path is taken from PowerShell's
        location, not from the process's working directory, which a .NET
        call would use. A path PowerShell cannot resolve, or one on another
        provider (Env:, HKCU:), throws a message that starts with -Subject.
    .PARAMETER Path
        The path to resolve.
    .PARAMETER Subject
        Where the path came from, as the start of a sentence, such as
        "GITHUB_OUTPUT is 'out.txt'" or "-Path is 'tools'".
    .PARAMETER Kind
        What the path should name, file or folder, for the message.
    .OUTPUTS
        The full path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Subject,

        [Parameter(Mandatory)]
        [ValidateSet('file', 'folder')]
        [string]$Kind
    )

    $provider = $null
    $drive = $null
    try {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $Path,
            [ref]$provider,
            [ref]$drive)
    }
    catch {
        $reason = $_.Exception.GetBaseException().Message
        # PowerShell's reason for a path it cannot resolve repeats a part of it, such as the name before its first ':'.
        if ((Hide-UrlCredential -Text $Path) -cne $Path) {
            $reason = 'the path holds a credential, so the reason PowerShell gives is not shown'
        }

        throw "$Subject, which PowerShell cannot resolve: $reason"
    }

    if ($provider.Name -ne 'FileSystem') {
        throw ("$Subject, which resolves to a path on the $($provider.Name) provider, not a $Kind; " +
            'give a full file-system path, or run from a file-system location.')
    }

    return $resolved
}
