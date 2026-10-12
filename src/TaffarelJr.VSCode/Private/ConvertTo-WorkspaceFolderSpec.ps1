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
        straight in.
    .PARAMETER Folder
        The value to normalize.
    .OUTPUTS
        An object with Path (never empty), Name, and Comment (each
        $null when not given).
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Folder
    )

    if ($Folder -is [string]) {
        return [PSCustomObject]@{
            Path    = $Folder
            Name    = $null
            Comment = $null
        }
    }

    $values = @{}
    foreach ($field in 'Path', 'FullName', 'Name', 'Comment') {
        if ($Folder -is [IDictionary]) {
            $values[$field] = $Folder[$field]
            continue
        }

        $property = $Folder.PSObject.Properties[$field]
        if ($property) {
            $values[$field] = $property.Value
        }
    }

    $path = $values['Path']
    if (-not $path) {
        $path = $values['FullName']
    }

    if (-not $path) {
        throw 'A workspace folder needs a Path.'
    }

    return [PSCustomObject]@{
        Path    = [string]$path
        Name    = $values['Name']
        Comment = $values['Comment']
    }
}
