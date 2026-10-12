using namespace System.Collections

function ConvertTo-GitHubLabelReference {
    <#
    .SYNOPSIS
        Returns a label's name, and the repository it belongs to when the
        label says so, from a name, a label's URL, or a label object.
    .DESCRIPTION
        Text is the label's name, unless it is a label's web URL
        (https://HOST/OWNER/REPO/labels/NAME), which is read like an
        object's Url. An object - one of Get-GitHubLabel's, or a hashtable
        - is read by its Name, and its repository by its Url, so a label
        listed from another repository is acted on there and not in the
        current directory's. An object without a Url (the labels on an
        issue or a pull request carry none) does not say its repository,
        so it needs one named.

        A repository the caller named is compared with the label's own by
        Assert-GitHubSameRepository: naming another one throws, since one
        of the two is wrong. When only the label names a host, its host is
        kept, so a GitHub Enterprise label stays on its own host.
    .PARAMETER Label
        A label's name or web URL, or a label object.
    .PARAMETER Repository
        The repository reference the caller named, if any.
    .OUTPUTS
        An object with Name and Repository: the repository to act on (the
        named one, or the label's own), else $null.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Label,

        [AllowEmptyString()]
        [string]$Repository
    )

    if ($null -eq $Label) {
        throw 'A label was given, but it is $null.'
    }

    if ($Label -isnot [string] -and $Label -isnot [IDictionary] -and $Label -is [IEnumerable]) {
        throw "Give one label at a time, not a list of $(@($Label).Count); pipe them to name several."
    }

    $labelUrl = '^(?<repository>https?://[^/\s]+/[^/\s]+/[^/\s]+)/labels/(?<name>\S+?)/?\z'
    $name = $Label
    $url = $null
    if ($Label -is [string]) {
        if ($Label -match '^https?://') {
            $url = $Label
        }
    }
    else {
        $values = @{}
        if ($Label -is [IDictionary]) {
            foreach ($key in $Label.PSBase.Keys) {
                $values["$key"] = $Label[$key]
            }
        }
        else {
            foreach ($property in $Label.PSObject.Properties) {
                $values[$property.Name] = $property.Value
            }
        }

        $name = $values['Name']
        $url = $values['Url']
        if (-not $name) {
            throw "A label object needs a Name, and this one has none: $($Label.GetType().Name)."
        }
    }

    $labelRepository = $null
    if ($url) {
        if ("$url" -notmatch $labelUrl) {
            $shown = Hide-UrlCredential -Text "$url"
            throw "'$shown' is not a label: a URL must end in /OWNER/REPO/labels/NAME."
        }

        $labelRepository = $Matches['repository']
        if ($Label -is [string]) {
            $name = [uri]::UnescapeDataString($Matches['name'])
        }
    }

    if ("$name".Trim().Length -eq 0) {
        throw "'$name' is not a label: give its name, or a label object."
    }

    if ($Label -isnot [string] -and -not $url -and -not $Repository) {
        $shown = Hide-UrlCredential -Text "$name"
        throw "The label '$shown' is an object with no Url, so it does not say its repository: give -Repository."
    }

    if ($Repository -and $labelRepository) {
        $labelRepository = Assert-GitHubSameRepository -Item "'$url'" -Origin $url -Repository $Repository -PassThru
    }
    elseif ($Repository) {
        $labelRepository = $Repository
    }

    return [PSCustomObject]@{
        Name       = "$name"
        Repository = $labelRepository
    }
}
