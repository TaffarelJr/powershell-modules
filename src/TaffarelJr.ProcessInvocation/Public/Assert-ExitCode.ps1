function Assert-ExitCode {
    <#
    .SYNOPSIS
        Throws when an exit code is non-zero.
    .DESCRIPTION
        For a command whose output already streamed to the console rather
        than being captured, so only the verdict is still needed.
        Invoke-NativeCommand is the better fit when the output is only
        interesting on failure.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
        Any credential a URL in it carries is hidden in the message, as
        Hide-UrlCredential hides it.
    .PARAMETER ExitCode
        The exit code to check. Defaults to $LASTEXITCODE, so the common
        case is just Assert-ExitCode 'Building' right after the native call
        it is checking. Zero when no native command has run yet.
    .INPUTS
        None.
    .OUTPUTS
        None. A zero exit code returns nothing; any other ends the call with
        a terminating error.
    .EXAMPLE
        & dotnet build
        Assert-ExitCode 'Building'

        Lets the build print as it goes, then throws
        "Building failed with exit code 1" if it failed.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ProcessInvocation/README.md
    .LINK
        Invoke-NativeCommand
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Activity,

        [int]$ExitCode = (Get-Variable -Name LASTEXITCODE -Scope Global -ValueOnly -ErrorAction Ignore)
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        if ($ExitCode -eq 0) {
            return
        }

        throw "$(Hide-UrlCredential -Text $Activity) failed with exit code $ExitCode"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
