function Test-InteractiveHost {
    <#
    .SYNOPSIS
        Reports whether this session can be expected to have a person at it.
    .DESCRIPTION
        Checked in this order: a CI environment variable wins outright
        (a real terminal attached to a CI runner is still not a person to
        prompt), then the -NonInteractive launch flag in any abbreviation,
        then [Environment]::UserInteractive, which is false only for a
        Windows service or a session-0 process, and always true on Linux and
        macOS. Input redirection is not considered: Read-Host still reads an
        answer piped in, so a closed or piped input does not make this false.

        CI is recognized by CI, GITHUB_ACTIONS, TF_BUILD (Azure Pipelines),
        GITLAB_CI, JENKINS_URL, TEAMCITY_VERSION, BUILDKITE, CIRCLECI,
        APPVEYOR, and TRAVIS. A variable set to nothing, 0, false, no, or off,
        in any casing, does not count: CI=false is how a person says "this is
        not CI".

        Within this module, a false answer does two things: Invoke-InputRetry
        stops retrying, and Wait-KeyPress returns without waiting. The prompt
        functions themselves still ask, so on CI an answer piped in is read,
        and with the input closed each prompt takes its default, or fails.
    .INPUTS
        None. Nothing can be piped in.
    .OUTPUTS
        System.Boolean. True when a person can be expected to answer.
    .EXAMPLE
        if (Test-InteractiveHost) { $name = Read-Input -Prompt 'Repo name' }

        Asks only where a person can answer.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Invoke-InputRetry
    .LINK
        Wait-KeyPress
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $ErrorActionPreference = 'Stop'

        foreach ($name in $script:CiVariableName) {
            $value = [Environment]::GetEnvironmentVariable($name)
            if (-not [string]::IsNullOrWhiteSpace($value) -and $value.Trim() -notin '0', 'false', 'no', 'off') {
                return $false
            }
        }

        $fact = Get-HostFact
        if (Test-NonInteractiveFlag -CommandLine $fact.CommandLine) {
            return $false
        }

        return $fact.UserInteractive
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
