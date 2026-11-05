function Resolve-RequiredModule {
    <#
    .SYNOPSIS
        Checks a required module an exported function was given, and returns
        it in the shape Get-RequiredModule returns.
    .DESCRIPTION
        Not exported. The functions that take modules as objects accept
        anything a caller can wrap in an object, so this is where the name
        and the minimum version are checked, by the same rules as a manifest
        entry (Get-RequiredModuleEntry): a name that is a pattern would
        install or import every module it matches, and a name starting with a
        dash would be read as a parameter of Install-Module.
    .PARAMETER Module
        What the caller gave: an object with a Name property and,
        optionally, MinimumVersion (a [Version] or text; $null means none)
        and DocumentationUrl. Any other property is ignored.
    .OUTPUTS
        A PSCustomObject with Name, MinimumVersion ($null when any version
        will do) and DocumentationUrl ($null when there is none). Throws,
        naming the module where it can, when the value is not valid.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Module
    )

    $properties = @()
    $type = '$null'
    if ($null -ne $Module) {
        $properties = @($Module.PSObject.Properties | ForEach-Object { $_.Name })
        $type = $Module.PSObject.BaseObject.GetType().Name
    }

    if ('Name' -notin $properties) {
        throw 'A required module must be an object with a Name property, as Get-RequiredModule returns one; ' +
        "got $type."
    }

    $entry = @{}
    foreach ($key in 'MinimumVersion', 'DocumentationUrl') {
        if ($key -in $properties -and $null -ne $Module.$key) {
            $entry[$key] = $Module.$key
        }
    }

    return Get-RequiredModuleEntry -Name $Module.Name -Entry $entry
}
