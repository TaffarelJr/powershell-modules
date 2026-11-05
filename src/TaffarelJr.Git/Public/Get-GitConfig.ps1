function Get-GitConfig {
    <#
    .SYNOPSIS
        Returns a config value, or $null when it is not set.
    .DESCRIPTION
        Without -Global, the value is the one git would use in the repo,
        from whichever scope sets it: the repo's own config, else the global
        or system config. With -Global, only the global config is read.
        Outside a repository, git reads only the global and system config,
        so the value from there comes back rather than an error.

        An empty value is a value: it comes back as an empty string, not
        $null. A key that git cannot read at all - an invalid name, an
        unreadable config file - throws instead of reading as unset, and so
        does a repository git refuses because another user owns it, whose
        own config git would skip without saying so.
    .PARAMETER Name
        The config key, such as 'user.name'. A credential it carries, as in
        a key that names a URL, is hidden in every message.
    .PARAMETER Global
        Reads only the global config, instead of the value in effect in the
        repo.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
        Not used with -Global, which reads the same file from anywhere,
        whatever repository an inherited GIT_DIR or GIT_CONFIG names.
    .INPUTS
        None. This function does not read the pipeline.
    .OUTPUTS
        System.String
        The config value, or nothing when it is not set.
    .EXAMPLE
        Get-GitConfig -Name 'user.email'

        Returns the email address git would use in the current repository.
    .EXAMPLE
        Get-GitConfig -Name 'user.name' -Global

        Returns the name in the global config only.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/README.md
    .LINK
        Set-GitConfig
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^(?!-)\S', ErrorMessage = "'{0}' is blank or starts with '-', which git reads as an option")]
        [string]$Name,

        [switch]$Global,

        [ValidatePattern('\S', ErrorMessage = '-RepoPath is blank: name a folder, or leave it out')]
        [string]$RepoPath
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $arguments = @('config')
        $in = $RepoPath
        if ($Global) {
            $arguments += '--global'
            $in = $null
        }

        $arguments += @('--get', $Name)

        $shownName = Hide-UrlCredential -Text $Name
        $read = Invoke-GitCommand -Activity "Reading $shownName" -Arguments $arguments -RepoPath $in `
            -NoRepository:$Global -Tolerant
        if ($read.Ok) {
            return $read.Output -join "`n"
        }

        # git config --get exits 1 for a key that is simply not set - and, as
        # silently, for one set only in a repository it refuses to read, which
        # Get-GitDirectory throws for.
        if ($read.ExitCode -eq 1 -and -not $read.Message) {
            if (-not $Global) {
                $inRepo = @{}
                if ($PSBoundParameters.ContainsKey('RepoPath')) {
                    $inRepo.RepoPath = $RepoPath
                }

                Get-GitDirectory @inRepo | Out-Null
            }

            return
        }

        throw "Reading $shownName failed (exit $($read.ExitCode)): $($read.Message)"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
