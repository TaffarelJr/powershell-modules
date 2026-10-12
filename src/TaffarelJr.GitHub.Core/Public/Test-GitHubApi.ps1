function Test-GitHubApi {
    <#
    .SYNOPSIS
        Reports whether a GET of an API endpoint succeeds, without
        throwing for an answer.
    .DESCRIPTION
        For a probe whose failure is the answer - does this resource
        exist - where a thrown error would be noise.

        Only "it is not there" is $false: GitHub answers 404 (it does not
        exist, or the token may not see it, which GitHub answers the same
        way) or 410 (it is gone). Every other failure is a failure to ask,
        not an answer, and throws with the HTTP status and gh's reason: a
        refused token (401), a forbidden one or a rate limit (403, 429), a
        server error, no network, no login, or gh missing. Reading those as
        "no" would report a resource gone because GitHub was briefly
        unreachable or the token was wrong. The message shows any
        credential a URL in it carries hidden.
    .PARAMETER Endpoint
        A REST path such as 'repos/cli/cli/immutable-releases'. One that is
        blank or starts with a dash is refused.
    .PARAMETER Hostname
        A GitHub host other than github.com, by its bare name, as
        Assert-GitHubHostname checks it. An empty value is refused; leave it
        out for the default host.
    .INPUTS
        None
    .OUTPUTS
        System.Boolean
        $true when the request succeeds, $false for a 404 or a 410.
    .EXAMPLE
        if (-not (Test-GitHubApi -Endpoint 'repos/cli/cli/pages')) {
            'no Pages site'
        }

        Asks whether cli/cli has a GitHub Pages site: a 404 is $false, while
        a 403, a rate limit, or a network failure throws rather than
        answering "no".
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('\S', ErrorMessage = '-Endpoint is blank: give a REST path such as repos/OWNER/REPO')]
        [ValidateScript({ Assert-GitHubEndpoint -Endpoint $_ })]
        [string]$Endpoint,

        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $arguments = @('api', $Endpoint, '--silent')
        if ($Hostname) {
            $arguments += @('--hostname', $Hostname)
        }

        $result = Invoke-GitHubCommand -Activity "Probing $Endpoint" -Argument $arguments -Tolerant
        if ($result.Ok) {
            return $true
        }

        if ((Get-GitHubHttpStatus -Message $result.Message) -in 404, 410) {
            return $false
        }

        throw (Format-GitHubFailure -Subject "Probing $Endpoint failed" -Result $result)
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
