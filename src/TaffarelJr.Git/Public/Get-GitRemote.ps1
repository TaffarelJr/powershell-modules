function Get-GitRemote {
    <#
    .SYNOPSIS
        Returns every remote's name, or one remote's URL by -Name.
    .DESCRIPTION
        With -Name, $null rather than a throw when that remote does not
        exist - a missing remote is often itself a legitimate answer (for
        example, walking a chain of repos until one has no more
        upstream), not a failure. Anything else git cannot answer, such as
        a folder that is no repository, throws.
    .PARAMETER Name
        The remote to read the URL of. Omit it to list every remote's name
        instead. A credential a URL given here by mistake carries is hidden
        in every message.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        The name of every remote; with -Name, that remote's URL, or nothing for
        a remote that does not exist.
    .EXAMPLE
        Get-GitRemote

        Lists the names of the remotes of the current repository.
    .EXAMPLE
        Get-GitRemote -Name 'origin'

        Returns the URL of the origin remote.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Set-GitRemote
    .LINK
        Remove-GitRemote
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        if (-not $Name) {
            return Invoke-GitCommand -Activity 'Listing remotes' -Arguments @('remote') -RepoPath $RepoPath
        }

        $shownName = Hide-UrlCredential -Text $Name
        $read = Invoke-GitCommand -Activity "Reading the $shownName remote" `
            -Arguments @('remote', 'get-url', $Name) -RepoPath $RepoPath -Tolerant

        # 2 is a remote that does not exist; anything else is git failing to
        # answer.
        if ($read.ExitCode -eq 2) {
            return
        }

        if (-not $read.Ok) {
            throw "Reading the $shownName remote failed (exit $($read.ExitCode)): $($read.Message)"
        }

        return ($read.Output -join '').Trim()
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
