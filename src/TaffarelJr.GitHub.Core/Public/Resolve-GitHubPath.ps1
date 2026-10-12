function Resolve-GitHubPath {
    <#
    .SYNOPSIS
        Returns the full file-system path gh is to be given for a path
        written the PowerShell way.
    .DESCRIPTION
        gh is a separate program: it knows nothing of PowerShell's current
        location (which the process's own directory does not follow),
        expands no ~, and has never heard of a PowerShell drive such as
        Temp:. So a path is resolved here, through the PowerShell provider,
        before gh sees it: relative to the current location, ~ as the home
        folder, a drive as the folder it stands for. The path need not
        exist - an output file or folder is resolved the same way.

        A path on any provider but the file system - HKCU:\x, or a relative
        path while the location is in the registry - throws, since there is
        no file there for gh to use. So does a path PowerShell cannot read
        at all, such as one starting with a drive it does not have: the
        message names the path, then PowerShell's own reason, unless the
        path holds a credential, when it shows the path with it hidden and
        no reason, since the reason repeats the part before the first colon.
    .PARAMETER Path
        The path as the caller gave it, taken literally: a wildcard
        character is part of the name.
    .INPUTS
        None
    .OUTPUTS
        System.String
        The full path.
    .EXAMPLE
        $folder = Resolve-GitHubPath -Path '~/downloads'

        Gives the downloads folder under the user's home, ready to pass to
        gh's --dir.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $ErrorActionPreference = 'Stop'

        $shown = Hide-UrlCredential -Text $Path
        $paths = $ExecutionContext.SessionState.Path
        $provider = $null
        $drive = $null
        try {
            $full = $paths.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
        }
        catch {
            $unreadable = "'$shown' is not a path PowerShell can read, so gh cannot use it"
            if ($shown -cne $Path) {
                throw "$unreadable."
            }

            throw "${unreadable}: $($_.Exception.GetBaseException().Message)"
        }

        if ($provider.Name -ne 'FileSystem') {
            throw "'$shown' is not a file system path (it is on the $($provider.Name) provider), so gh cannot use it."
        }

        return $full
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
