using namespace System.Collections

function ConvertTo-GitHubGistId {
    <#
    .SYNOPSIS
        Returns a gist's bare id, from its id, a URL of it, or a gist
        object.
    .DESCRIPTION
        A URL may be any of the https and SSH URLs GitHub gives for a gist:
        its page, with or without the owner and with whatever a browser
        adds (/raw/..., /revisions, a revision, ?query, #file-...), its
        clone URL (.git, or git@gist.github.com:{id}.git), its embed URLs
        (.js, .pibb), a raw file URL on gist.githubusercontent.com, its
        API URL (api.github.com/gists/{id}), or an enterprise server's
        forms: a gist. host (gist.ghe.example.com/...; a valid host name,
        never github.com's with labels after it), /gist/..., and
        /api/v3/gists/. A [uri] is read as the text it was made from.
        Only the id is kept: gh sends it to its own default host,
        whichever host the URL named.

        The id a URL holds must have an id's shape - 20 or 32
        hexadecimal digits, or a decimal number - so a user's page
        (/TaffarelJr, /me/starred) or one of GitHub's own (/discover,
        /auth/github) is never read as a gist.

        An object - one of Get-GitHubGist's - is read by its Id when that
        is text, else by its HtmlUrl, else by its Url; a whole number is
        the id of an old gist. A list of one is read as that one, as
        @(Get-GitHubGist ...) gives; a longer one throws, and so does
        anything else, so a value that is not an id - least of all one
        starting with a dash - never reaches gh.

        A parameter that takes both a value and an object by pipeline must
        be an [object]: as a [string], PowerShell turns a piped object into
        its text ("@{HtmlUrl=...}") instead of reading it.
    .PARAMETER Id
        A gist's id or URL, or a gist object.
    .OUTPUTS
        The bare id.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Id
    )

    if ($Id -isnot [string] -and $Id -isnot [IDictionary] -and $Id -is [IEnumerable]) {
        $items = @($Id)
        if ($items.Count -eq 1) {
            $Id = $items[0]
        }
    }

    if ($null -eq $Id) {
        throw 'A gist was given, but it is $null: give its id or URL, or a gist object.'
    }

    $integral = $false
    foreach ($type in [byte], [sbyte], [int16], [uint16], [int], [uint32], [long], [uint64], [bigint]) {
        if ($Id -is $type) {
            $integral = $true
            break
        }
    }

    $reference = $Id
    if ($integral) {
        $reference = "$Id"
    }
    elseif ($Id -is [uri]) {
        $reference = $Id.OriginalString
    }
    elseif ($Id -isnot [string]) {
        if ($Id -isnot [IDictionary] -and $Id -is [IEnumerable]) {
            throw "Give one gist at a time, not a list of $(@($Id).Count); pipe them to name several."
        }

        $values = @{}
        if ($Id -is [IDictionary]) {
            foreach ($key in $Id.PSBase.Keys) {
                $values["$key"] = $Id[$key]
            }
        }
        else {
            foreach ($property in $Id.PSObject.Properties) {
                $values[$property.Name] = $property.Value
            }
        }

        $reference = $null
        foreach ($name in 'Id', 'HtmlUrl', 'Url') {
            if ($values[$name] -is [string] -and $values[$name]) {
                $reference = $values[$name]
                break
            }
        }

        if ($null -eq $reference) {
            throw "A gist object needs an Id, an HtmlUrl, or a Url, and this one has none: $($Id.GetType().Name)."
        }
    }

    $text = [string]$reference
    $idPattern = '^[0-9A-Za-z]+\z'
    if ($text -cmatch $idPattern) {
        return $text
    }

    # A gist. host is a valid host name, and never github.com's own with
    # more labels after it.
    $gistHost = '^gist(\.(?!-)[a-z0-9-]{1,63}(?<!-))+\z'
    $lookAlike = '\.github(usercontent)?\.com\.'
    $candidate = $null
    $uri = $null
    if ($text -match '^git@([^:/\s]+):([^/\s]+?)(?:\.git)?/?\z') {
        $sshHost = $Matches[1]
        $sshId = $Matches[2]
        if ($sshHost -match $gistHost -and $sshHost -notmatch $lookAlike) {
            $candidate = $sshId
        }
    }
    elseif ($text -match '^https?://' -and [uri]::TryCreate($text, [UriKind]::Absolute, [ref]$uri)) {
        $segments = @($uri.AbsolutePath.Split('/', [StringSplitOptions]::RemoveEmptyEntries))
        $api = $false
        if ($uri.Host -eq 'api.github.com') {
            $api = $true
        }
        elseif ($uri.Host -notmatch $gistHost -or $uri.Host -match $lookAlike) {
            if ($segments.Count -gt 0 -and $segments[0] -ceq 'gist') {
                $segments = @($segments | Select-Object -Skip 1)
            }
            elseif ($segments.Count -gt 2 -and $segments[0] -ceq 'api' -and $segments[1] -ceq 'v3') {
                $segments = @($segments | Select-Object -Skip 2)
                $api = $true
            }
            else {
                $segments = @()
            }
        }

        if ($api) {
            if ($segments.Count -ge 2 -and $segments[0] -ceq 'gists') {
                $candidate = $segments[1]
            }
        }
        elseif ($segments.Count -gt 0) {
            # The owner is optional, so /x/y is either OWNER/ID or ID/SUFFIX:
            # a suffix GitHub puts after an id, or a 40-hex revision, marks
            # the second; an owner (39 characters at most) is never 40-hex.
            $suffix = $false
            if ($segments.Count -ge 2) {
                $named = $segments[1] -cin @('raw', 'revisions', 'forks', 'stargazers')
                $suffix = $named -or ($segments[1] -match '^[0-9a-f]{40}\z')
            }

            $candidate = if ($suffix -or $segments.Count -eq 1) { $segments[0] } else { $segments[1] }
            $candidate = $candidate -creplace '\.(git|js|pibb)\z', ''
        }
    }

    if ($candidate -match '^([0-9a-f]{20}|[0-9a-f]{32}|[0-9]+)\z') {
        return $candidate
    }

    $shown = Hide-UrlCredential -Text $text
    throw "'$shown' is not a gist: give its id or URL, or a gist object."
}
