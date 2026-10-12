using namespace System.Collections

function ConvertTo-WorkspaceFolderSpec {
    <#
    .SYNOPSIS
        Normalizes one -Folder value into a Path, Name, and Comment.
    .DESCRIPTION
        Not exported. A folder can be given as a bare path, as a
        dictionary or object carrying Path with an optional Name and
        Comment, or as a FileInfo or DirectoryInfo - which has FullName
        and Name but no Path - so that Get-ChildItem output pipes
        straight in. A dictionary's entries are matched in any casing,
        and a key that is not a string is skipped. A path that is empty or
        only whitespace is refused in every form, rather than resolving to the
        current folder.
    .PARAMETER Folder
        The value to normalize.
    .OUTPUTS
        An object with Path (never blank), Name, and Comment (each
        $null when not given).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Folder
    )

    if ($null -eq $Folder) {
        throw ('A workspace folder is $null. Give each folder as a path, a dictionary or object ' +
            'with a Path, or a DirectoryInfo.')
    }

    $values = @{}
    if ($Folder -is [string]) {
        $values['Path'] = $Folder
    }
    else {
        foreach ($field in 'Path', 'FullName', 'Name', 'Comment') {
            if ($Folder -is [IDictionary]) {
                $values[$field] = Get-DictionaryValue -Dictionary $Folder -Name $field
                continue
            }

            $property = $Folder.PSObject.Properties[$field]
            if ($property) {
                $values[$field] = $property.Value
            }
        }
    }

    $path = $values['Path']
    if (-not $path) {
        $path = $values['FullName']
    }

    if ([string]::IsNullOrWhiteSpace([string]$path)) {
        throw 'A workspace folder needs a Path.'
    }

    return [PSCustomObject]@{
        Path    = [string]$path
        Name    = $values['Name']
        Comment = $values['Comment']
    }
}
