function Test-GitHubApi {
    <#
    .SYNOPSIS
        Reports whether a GET of an API endpoint succeeds, without
        throwing.
    .DESCRIPTION
        For a probe whose failure is the answer - does this resource
        exist, does the current token have access to it - where a thrown
        error would be noise.
    .PARAMETER Endpoint
        A REST path such as 'repos/{owner}/{repo}/immutable-releases'.
    .PARAMETER Hostname
        A GitHub host other than github.com.
    .OUTPUTS
        $true when the request succeeds, $false otherwise - including
        when gh has no usable authentication.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Endpoint,

        [string]$Hostname
    )

    $arguments = @('api', $Endpoint, '--silent')
    if ($Hostname) {
        $arguments += @('--hostname', $Hostname)
    }

    $result = Invoke-GitHubCommand -Activity "Probing $Endpoint" -Arguments $arguments -Tolerant
    return $result.Ok
}
