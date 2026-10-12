using namespace System.Collections
using namespace System.Collections.Generic

function Get-GitHubApiMask {
    <#
    .SYNOPSIS
        Returns the values of an API call that a message must not show: every
        header's, and each field's whose key names a secret.
    .DESCRIPTION
        Not exported. What Invoke-GitHubApi gives Invoke-GitHubCommand as
        -Mask. A field is read from the arguments gh is given for it, the
        flag and then name=value, so a nested name such as config[secret],
        and a list's key[], are matched as gh reads them. A key names a secret
        when it holds secret, token, passw, credential, auth, api-key (or
        api_key, apikey), private, or signature, in any case; the whole
        bracketed name is matched, so a value nested under such a key is one
        too.

        The text true, false, and null is never returned: gh types a bool or
        a $null as it, so it is no secret, and hiding it would garble every
        other field that holds one. An empty value is left out too.
    .PARAMETER FieldArgument
        The arguments ConvertTo-GitHubFieldArgument made, for --field and
        --raw-field alike: alternating a flag and a name=value pair.
    .PARAMETER Header
        The request headers, as a hashtable of name to value.
    .OUTPUTS
        Each value to hide, one at a time.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyCollection()]
        [string[]]$FieldArgument = @(),

        [IDictionary]$Header
    )

    $secretKey = '(?i)secret|token|passw|credential|auth|api[-_]?key|private|signature'
    $values = [List[string]]::new()
    for ($index = 1; $index -lt $FieldArgument.Count; $index += 2) {
        $pair = $FieldArgument[$index]
        $equals = $pair.IndexOf('=')
        if ($equals -lt 0) {
            continue
        }

        $key = $pair.Substring(0, $equals)
        $value = $pair.Substring($equals + 1)
        $isTyped = $value -cin 'true', 'false', 'null'
        if ($value -and -not $isTyped -and $key -match $secretKey) {
            $values.Add($value)
        }
    }

    if ($Header) {
        foreach ($name in $Header.PSBase.Keys) {
            $text = "$($Header[$name])"
            if ($text) {
                $values.Add($text)
            }
        }
    }

    return $values.ToArray()
}
