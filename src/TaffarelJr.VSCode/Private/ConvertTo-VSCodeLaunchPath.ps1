using namespace System.Collections

function ConvertTo-VSCodeLaunchPath {
    <#
    .SYNOPSIS
        Turns one thing to open in VS Code into an absolute file system
        path.
    .DESCRIPTION
        Not exported. A string is the path itself; any other object gives
        its Path property, or failing that its FullName, as a PathInfo or
        a FileInfo carries - never its text, which for a listing object is
        '@{Number=7; ...}'. A dictionary gives its Path or FullName entry,
        in any casing, skipping keys that are not strings. A blank path is
        refused rather than opening the current folder. A relative path
        resolves against PowerShell's current location, and a path in any
        provider other than the file system - the registry, Env:\ - is
        refused, having no file behind it.
    .PARAMETER InputObject
        The string or object to resolve.
    .OUTPUTS
        The absolute file system path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $text = $InputObject
    if ($InputObject -isnot [string]) {
        $text = $null
        foreach ($name in 'Path', 'FullName') {
            $value = $null
            if ($InputObject -is [IDictionary]) {
                $value = Get-DictionaryValue -Dictionary $InputObject -Name $name
            }
            else {
                $property = $InputObject.PSObject.Properties[$name]
                if ($property) {
                    $value = $property.Value
                }
            }

            if ($value) {
                $text = [string]$value
                break
            }
        }

        if ($null -eq $text) {
            $type = $InputObject.GetType().FullName
            throw "Cannot open a $type in VS Code: it has no Path or FullName property. Give a path instead."
        }
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        throw '-Path is empty or only whitespace. Give a folder, workspace, or file to open.'
    }

    $provider = $null
    $drive = $null
    $sessionPath = $ExecutionContext.SessionState.Path
    try {
        $path = $sessionPath.GetUnresolvedProviderPathFromPSPath($text, [ref]$provider, [ref]$drive)
    }
    catch {
        throw "Cannot open '$text' in VS Code: $($_.Exception.GetBaseException().Message)"
    }

    if ($provider.Name -ne 'FileSystem') {
        throw "VS Code opens file system paths only, and this is in the $($provider.Name) provider: $text"
    }

    return $path
}
