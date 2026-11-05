function Assert-GitHubHostname {
    <#
    .SYNOPSIS
        Throws unless a value is a host name gh can look up, and returns
        $true otherwise.
    .DESCRIPTION
        The one check behind every -Hostname of the TaffarelJr.GitHub.*
        modules, written to run from a parameter's ValidateScript, which
        needs $true back.

        gh stores and finds a host by its bare name, so a host passes only
        as labels of letters (combining marks included, but not first),
        digits, dashes, and underscores, joined by single dots, with at
        least one letter or digit, no label that starts or ends with a dash,
        and within DNS's limits: at most 63 octets a label and 253 in all,
        counted in the ASCII (Punycode) form a non-ASCII name takes. A URL,
        a port, or a path is refused here as gh auth login refuses them; a
        user (user@host), a space of any kind - a zero-width one included -
        a wildcard, an empty label (a..b), and a trailing dot are refused
        too, since gh would only fail to find such a host later (it stores
        github.com. apart from github.com). A leading dash would be read as
        an option.

        An empty value is refused too: a lookup that came back with
        nothing must not mean the default host. Leave the parameter out
        for that.
    .PARAMETER Hostname
        The host name to check.
    .INPUTS
        None
    .OUTPUTS
        System.Boolean
        $true when the value passes; any other value throws.
    .EXAMPLE
        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname

        Refuses -Hostname 'https://ghe.example.com' with
        "'https://ghe.example.com' is not a host name: give it bare, such as
        github.com ...".
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Hostname
    )

    try {
        $ErrorActionPreference = 'Stop'

        $shown = Hide-UrlCredential -Text $Hostname
        $label = '[\p{L}\p{N}_](?:[\p{L}\p{M}\p{N}_-]*[\p{L}\p{M}\p{N}_])?'
        if ($Hostname -notmatch "^(?=.*[\p{L}\p{N}])$label(?:\.$label)*\z") {
            throw "'$shown' is not a host name: give it bare, such as github.com - labels of letters, digits," +
            ' dashes, and underscores joined by single dots, none starting or ending with a dash, and no scheme,' +
            ' port, path, space, or trailing dot - or leave -Hostname out for the default host.'
        }

        # DNS limits the ASCII (Punycode) form, which is longer than the text for a non-ASCII label.
        try {
            $ascii = [System.Globalization.IdnMapping]::new().GetAscii($Hostname)
        }
        catch [System.ArgumentException] {
            $ascii = $null
        }

        $tooLong = $null -eq $ascii -or $ascii.Length -gt 253
        if (-not $tooLong) {
            $tooLong = @($ascii.Split('.') | Where-Object Length -GT 63).Count -gt 0
        }

        if ($tooLong) {
            throw "'$shown' is not a host name DNS can hold: a label is at most 63 octets in its ASCII (Punycode)" +
            ' form, and the whole name at most 253.'
        }

        return $true
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
