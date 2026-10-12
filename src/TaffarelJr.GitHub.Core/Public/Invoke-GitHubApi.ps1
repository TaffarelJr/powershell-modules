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
        gh's. Values are parsed as ConvertFrom-GitHubJson describes: a
        string stays a string, and only a timestamp under a key ending in
        _at (or At, or Date) becomes a [datetime].

        Giving any -Field or -RawField, or a -Body, switches gh's default
        method from GET to POST, as gh itself does; pass -Method GET to send
        fields as a query string instead.

        -WhatIf and -Confirm cover a call that can change something: any
        method but GET and HEAD, to any endpoint but graphql, whose every
        query is a POST. With -WhatIf such a call is not made and nothing is
        returned; a read is made as usual.

        With -Verbose, the call is described before it is made, and then
        the gh command line that makes it, as Invoke-GitHubCommand
        writes it. Neither shows the -Body text.

        A secret in a message: the value of every -Header, and the value of
        every -Field or -RawField whose key names one - it holds secret,
        token, passw, credential, auth, api-key, private, or signature, in
        any case, also nested as in config[secret] - is shown as *** in
        -Verbose output and in every failure message. The text true, false,
        and null is never hidden. Any other secret belongs in -Body, which is
        sent on standard input and never shown.
    .PARAMETER Endpoint
        A REST path such as 'repos/cli/cli/releases', or 'graphql'. gh
        fills {owner}, {repo}, and {branch} from the git repository in the
        current directory, and fails outside one. One that is blank or
        starts with a dash is refused. A message shows it with any
        credential a URL carries, and any GitHub token on its own, hidden.
    .PARAMETER Method
        The HTTP method. gh defaults to GET, or to POST once any field or a
        -Body is given.
    .PARAMETER Field
        Typed parameters (gh's -F): a bool, integer, or $null is sent as
        its JSON type, a string starting with @ is read from that file,
        and an array is sent as one key[]=value per element. gh types a
        string by its looks too - 'true', 'null', and '123' become a
        bool, null, and number, and '007' becomes 7 - so a string that
        must stay one, or that comes from outside, belongs in -RawField.
        Only an integer that fits a 64-bit number is sent as a JSON number:
        a fraction, a larger integer, an enum, a TimeSpan, or a char is
        sent as a string. A value that is exactly {owner}, {repo}, or
        {branch} is filled in from the current directory's git repository,
        as in -Endpoint.
    .PARAMETER RawField
        String parameters (gh's -f), sent as-is, never typed and never read
        from a file. A GraphQL query goes here. A $null value is sent as
        the text "null".
    .PARAMETER Header
        Extra request headers, as a hashtable of name to value. The value of
        every header is hidden in messages, which show *** in its place.
        gh sends its own authentication, and a secret body goes in -Body.
    .PARAMETER Body
        A pre-built request body, typically JSON, piped to gh on standard
        input as UTF-8 and ended with a newline. With a body, any
        -Field/-RawField goes to the query string. An empty string is a
        body too; $null, or anything that is not text, such as a hashtable,
        is refused.
    .PARAMETER Jq
        A jq expression applied to the response. The result comes back
        as text lines, not parsed.
    .PARAMETER Paginate
        Fetches every page. For a REST list endpoint the pages are
        flattened into one sequence of items; pages that are objects, as
        from GraphQL, come back one page object at a time. gh pages only a
        GET for a REST endpoint, so with a -Method other than GET this
        throws for any endpoint but graphql.
    .PARAMETER Preview
        API preview names to opt into, without the '-preview' suffix.
    .PARAMETER Hostname
        A GitHub host other than github.com, by its bare name, as
        Assert-GitHubHostname checks it. An empty value is refused; leave it
        out for the default host.
    .PARAMETER Raw
        Returns the response as text lines instead of parsing it, for a
        response that is not JSON at all.
    .PARAMETER Silent
        Discards the response body and returns nothing.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        The parsed response: an object, or for a JSON array its elements
        one at a time, so wrap the call in @() to collect a list.
        System.String
        Text lines with -Jq or -Raw. Nothing for an empty body, or with
        -Silent.
    .EXAMPLE
        $endpoint = 'repos/cli/cli/releases?per_page=100'
        $releases = @(Invoke-GitHubApi -Endpoint $endpoint -Paginate)

        Collects every release of cli/cli across all pages, each with
        GitHub's own field names (tag_name, published_at).
    .EXAMPLE
        $body = $ruleset | ConvertTo-Json -Depth 10
        Invoke-GitHubApi -Endpoint 'repos/o/r/rulesets' -Method POST -Body $body

        Sends a request body that -Field cannot express - a list of
        objects - as JSON on standard input.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject], [string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('\S', ErrorMessage = '-Endpoint is blank: give a REST path, or graphql')]
        [ValidateScript({ Assert-GitHubEndpoint -Endpoint $_ })]
        [string]$Endpoint,

        [string]$Method,

        [System.Collections.IDictionary]$Field,

        [System.Collections.IDictionary]$RawField,

        [System.Collections.IDictionary]$Header,

        [AllowNull()]
        [object]$Body,

        [string]$Jq,

        [switch]$Paginate,

        [string[]]$Preview,

        [ValidateScript({ Assert-GitHubHostname -Hostname $_ })]
        [string]$Hostname,

        [switch]$Raw,

        [switch]$Silent
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $hasBody = $PSBoundParameters.ContainsKey('Body')
        if ($hasBody -and $null -eq $Body) {
            throw '-Body is $null: give the request body as text, or leave -Body out to send none.'
        }

        if ($hasBody -and $Body -isnot [string]) {
            throw "-Body is a $($Body.GetType().Name): give the request body as text, such as ConvertTo-Json writes it."
        }

        $verb = "$Method".ToUpperInvariant()
        $shownEndpoint = Hide-GitHubCredential -Text $Endpoint
        if ($Paginate -and $verb -and $verb -ne 'GET' -and $Endpoint -ne 'graphql') {
            throw "Calling $shownEndpoint with -Paginate needs -Method GET: gh fetches further pages only for a" +
            " GET of a REST endpoint (or for graphql), and refuses --paginate with $(Hide-UrlCredential $verb)."
        }

        $parse = -not ($Silent -or $Raw -or $Jq)

        $arguments = @('api', $Endpoint)
        if ($verb) {
            $arguments += @('--method', $verb)
        }

        $fieldArguments = @(ConvertTo-GitHubFieldArgument -Flag '--field' -Field $Field)
        $rawArguments = @(ConvertTo-GitHubFieldArgument -Flag '--raw-field' -Field $RawField)
        $arguments += $fieldArguments
        $arguments += $rawArguments
        $mask = @(Get-GitHubApiMask -FieldArgument ($fieldArguments + $rawArguments) -Header $Header)
        if ($Header) {
            $names = $Header.PSBase.Keys | Sort-Object
            foreach ($name in $names) {
                $arguments += @('--header', "$($name): $($Header[$name])")
            }
        }

        if ($PSBoundParameters.ContainsKey('Body')) {
            $arguments += @('--input', '-')
        }

        if ($Jq) {
            $arguments += @('--jq', $Jq)
        }

        # gh refuses --slurp beside --jq, so it is only asked for when the pages are parsed here.
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

        $effective = if ($verb) {
            $verb
        }
        elseif ($fieldArguments.Count -gt 0 -or $rawArguments.Count -gt 0 -or $hasBody) {
            'POST'
        }
        else {
            'GET'
        }

        $changes = $effective -cnotin 'GET', 'HEAD' -and $Endpoint -cne 'graphql'
        $target = "$(Hide-UrlCredential -Text $effective) $shownEndpoint"
        if ($changes -and -not $PSCmdlet.ShouldProcess($target, 'Call the GitHub API')) {
            return
        }

        $sentVerb = if ($verb) { $verb } else { "gh's default method" }
        Write-Verbose "Calling $shownEndpoint with $sentVerb"
        $out = Invoke-GitHubCommand -Activity "Calling $Endpoint" -Argument $arguments -Mask $mask @extra
        if ($Silent) {
            return
        }

        if (-not $parse) {
            return $out
        }

        # Parsed whole, so a one-element page can still be told from an object.
        try {
            $response = ConvertFrom-GitHubJson -Line $out -KeepFieldNames -NoEnumerate
        }
        catch [System.IO.InvalidDataException] {
            $reason = Hide-MaskedValue -Text $_.Exception.Message -Mask $mask
            throw "The response from $shownEndpoint is not JSON - give -Raw to read it as text. $reason"
        }

        if ($Paginate -and $response -is [array]) {
            $listPages = $true
            foreach ($page in $response) {
                if ($page -isnot [array]) {
                    $listPages = $false
                    break
                }
            }

            if ($listPages) {
                foreach ($page in $response) {
                    $page
                }

                return
            }
        }

        return $response
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
