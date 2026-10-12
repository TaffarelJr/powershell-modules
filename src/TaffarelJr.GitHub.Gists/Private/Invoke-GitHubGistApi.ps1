function Invoke-GitHubGistApi {
    <#
    .SYNOPSIS
        Calls GitHub's API for a gist, and on failure throws in the words
        of what the caller was doing rather than the endpoint's.
    .PARAMETER Activity
        What the call does, for the failure message: 'Reading gist abc'.
    .PARAMETER Request
        The parameters for Invoke-GitHubApi, Endpoint included.
    .OUTPUTS
        Whatever Invoke-GitHubApi returns.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [hashtable]$Request
    )

    try {
        Invoke-GitHubApi @Request
    }
    catch {
        $message = $_.Exception.Message
        $generic = "Calling $($Request['Endpoint']) failed: "
        if ($message.StartsWith($generic, [StringComparison]::Ordinal)) {
            $message = $message.Substring($generic.Length)
        }

        throw [System.InvalidOperationException]::new("$Activity failed: $message", $_.Exception)
    }
}
