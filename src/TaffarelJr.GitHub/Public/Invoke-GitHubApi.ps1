function Invoke-GitHubApi {
    <#
    .SYNOPSIS
        Makes an authenticated request to the GitHub REST or GraphQL API
        and returns the parsed response.
    .DESCRIPTION
        The escape hatch for anything gh has no dedicated subcommand for.
        The response keeps its field names exactly as GitHub sent them -
        snake_case for REST - so every property lines up with GitHub's
        own API documentation. This is the one place this module does not
        re-case to PascalCase: here GitHub's schema is the contract, not
        gh's.

        Giving any -Field or -RawField switches gh's default method from
        GET to POST, as gh itself does; pass -Method GET to send them as
        a query string instead.
    .PARAMETER Endpoint
        A REST path such as 'repos/{owner}/{repo}/releases', or 'graphql'.
        gh fills {owner}, {repo}, and {branch} from the current
        directory's repository.
    .PARAMETER Method
        The HTTP method. gh defaults to GET, or to POST once any field is
        given.
    .PARAMETER Field
        Typed parameters (gh's -F): a bool, integer, or $null is sent as
        its JSON type, a string starting with @ is read from that file,
        and an array is sent as one key[]=value per element.
    .PARAMETER RawField
        String parameters (gh's -f), sent as-is. A GraphQL query goes
        here.
    .PARAMETER Header
        Extra request headers, as a hashtable of name to value.
    .PARAMETER Body
        A pre-built request body, typically JSON, piped to gh on standard
        input. With a body, any -Field/-RawField goes to the query string.
    .PARAMETER Jq
        A jq expression applied to the response. The result comes back
        as text lines, not parsed.
    .PARAMETER Paginate
        Fetches every page. For a REST list endpoint the pages are
        flattened into one array of items; pages that are objects, as
        from GraphQL, come back as one array of page objects.
    .PARAMETER Preview
        API preview names to opt into, without the '-preview' suffix.
    .PARAMETER Hostname
        A GitHub host other than github.com.
    .PARAMETER Raw
        Returns the response as text lines instead of parsing it, for a
        response that is not JSON at all.
    .PARAMETER Silent
        Discards the response body and returns nothing.
    .OUTPUTS
        The parsed response: an object, an array (always, even with one
        element or none), or $null for an empty body. Text lines with -Jq
        or -Raw, always an array. Nothing with -Silent.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Endpoint,

        [string]$Method,

        [hashtable]$Field,

        [hashtable]$RawField,

        [hashtable]$Header,

        [string]$Body,

        [string]$Jq,

        [switch]$Paginate,

        [string[]]$Preview,

        [string]$Hostname,

        [switch]$Raw,

        [switch]$Silent
    )

    $parse = -not ($Silent -or $Raw -or $Jq)

    $arguments = @('api', $Endpoint)
    if ($Method) {
        $arguments += @('--method', $Method.ToUpperInvariant())
    }

    $arguments += ConvertTo-GitHubFieldArgument -Flag '--field' -Fields $Field
    $arguments += ConvertTo-GitHubFieldArgument -Flag '--raw-field' -Fields $RawField
    if ($Header) {
        foreach ($name in ($Header.Keys | Sort-Object)) {
            $arguments += @('--header', "$($name): $($Header[$name])")
        }
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $arguments += @('--input', '-')
    }

    if ($Jq) {
        $arguments += @('--jq', $Jq)
    }

    if ($Paginate) {
        $arguments += '--paginate'
        if ($parse) {
            $arguments += '--slurp'
        }
    }

    foreach ($name in $Preview) {
        $arguments += @('--preview', $name)
    }

    if ($Hostname) {
        $arguments += @('--hostname', $Hostname)
    }

    if ($Silent) {
        $arguments += '--silent'
    }

    $extra = @{}
    if ($PSBoundParameters.ContainsKey('Body')) {
        $extra['StdIn'] = $Body
    }

    $out = Invoke-GitHubCommand -Activity "Calling $Endpoint" -Arguments $arguments @extra
    if ($Silent) {
        return
    }

    if (-not $parse) {
        return , $out
    }

    $response = ConvertFrom-GitHubJson -Lines $out -KeepFieldNames
    if ($Paginate -and $response -is [array]) {
        $objectPages = @($response | Where-Object { $_ -isnot [array] })
        if ($objectPages.Count -eq 0) {
            $items = @(foreach ($page in $response) { $page })
            return , $items
        }
    }

    if ($response -is [array]) {
        return , $response
    }

    return $response
}
