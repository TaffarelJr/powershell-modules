function Resolve-GitHubInputFile {
    <#
    .SYNOPSIS
        Returns the full path of a file gh is to read, or throws when it
        is not one.
    .DESCRIPTION
        The path is resolved as Resolve-GitHubPath does - relative to
        PowerShell's location, ~ expanded, a drive resolved - and must then
        name an existing file, not a folder. It is taken literally: a name
        holding '[' or ']' is that file, never a pattern.

        A lone '-' is refused first, since gh reads it as standard input
        and then waits on it.
    .PARAMETER Path
        The path as the caller gave it.
    .PARAMETER Name
        The parameter the path came from, without its dash, put in front of
        the message: "-KeyFile 'x' is not a file." Leave it out for a
        message that names only the path.
    .INPUTS
        None
    .OUTPUTS
        System.String
        The full path.
    .EXAMPLE
        $key = Resolve-GitHubInputFile -Path '~/keys/deploy.pub' -Name 'KeyFile'

        Gives the key file's full path, or throws
        "-KeyFile '~/.ssh/id_ed25519.pub' is not a file."
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidatePattern('^\w+\z', ErrorMessage = "'{0}' is not a parameter name: give it without its dash.")]
        [string]$Name
    )

    try {
        $ErrorActionPreference = 'Stop'

        $shown = Hide-UrlCredential -Text $Path
        $subject = if ($Name) { "-$Name '$shown'" } else { "'$shown'" }
        if ($Path.Trim() -eq '-') {
            throw "$subject would make gh read standard input: give the path of a file."
        }

        $full = Resolve-GitHubPath -Path $Path
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            throw "$subject is not a file."
        }

        return $full
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
