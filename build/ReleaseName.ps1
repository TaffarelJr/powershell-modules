#Requires -Version 7.6

<#
.SYNOPSIS
    How a module is named, and how its releases are tagged.

.DESCRIPTION
    Dot-source this file. It defines functions and runs nothing.

    A module's full name, TaffarelJr.<Name>, is what the PowerShell Gallery
    and its folder under src/ need. Everywhere else a module is called by its
    short name, <Name>, and a release of it is tagged <Name>/vX.Y.Z. A short
    name is letters and digits, starting with a letter, in parts separated by
    dots, such as Tally or GitHub.Core. It never holds a slash, so the first
    /v after it always starts the version, and the name of one module is never
    the start of another module's tag.

    Every function takes a short name or a full one, and the scripts that
    call them accept either from the person running them.
#>

function Get-ShortModuleName {
    <#
    .SYNOPSIS
        Returns a module's name without the TaffarelJr namespace.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Module
    )

    $namespace = 'TaffarelJr.'
    if ($Module.StartsWith($namespace, [StringComparison]::Ordinal)) {
        return $Module.Substring($namespace.Length)
    }

    return $Module
}

function Test-ShortModuleName {
    <#
    .SYNOPSIS
        Says whether text is a short module name: letters and digits, starting
        with a letter, in dot-separated parts, and not itself carrying the
        namespace.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name
    )

    $shape = '^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*\z'
    return ($Name -cmatch $shape) -and ($Name -cnotlike 'TaffarelJr.*')
}

function Resolve-ModuleName {
    <#
    .SYNOPSIS
        Returns a module's full name from a short or a full one, refusing what
        is not a module name. With -SourceRoot the module must also be a
        folder there, spelled exactly, on every platform.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [string]$SourceRoot
    )

    $short = Get-ShortModuleName -Module $Name
    if (-not (Test-ShortModuleName -Name $short)) {
        throw "'$Name' is not a module name: a name is letters and digits, " +
        'starting with a letter, in parts separated by dots, such as Tally or GitHub.Core.'
    }

    $full = "TaffarelJr.$short"
    if ($SourceRoot) {
        $entries = Get-ChildItem -LiteralPath $SourceRoot -Directory -ErrorAction SilentlyContinue
        $folders = @($entries | ForEach-Object Name)
        if ($full -cnotin $folders) {
            throw "There is no module folder named '$full' under '$SourceRoot'."
        }
    }

    return $full
}

function Get-ReleaseTag {
    <#
    .SYNOPSIS
        Returns the tag of a module's release: <Name>/vX.Y.Z.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Module,

        [Parameter(Mandatory)]
        [string]$Version
    )

    if ($Version -notmatch '^\d+\.\d+\.\d+\z') {
        throw "Version '$Version' is not MAJOR.MINOR.PATCH, three numbers such as 0.2.0."
    }

    $short = Get-ShortModuleName -Module (Resolve-ModuleName -Name $Module)
    return "$short/v$Version"
}

function Get-ReleaseTagGlob {
    <#
    .SYNOPSIS
        Returns the pattern git lists a module's release tags by.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Module
    )

    $short = Get-ShortModuleName -Module (Resolve-ModuleName -Name $Module)
    return "$short/v*"
}

function Get-ReleaseTagRegex {
    <#
    .SYNOPSIS
        Returns the regular expression git-cliff matches a module's release
        tags by: this module's, and no other module's.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Module
    )

    $short = Get-ShortModuleName -Module (Resolve-ModuleName -Name $Module)
    return '^' + [regex]::Escape($short) + '/v[0-9].*'
}

function ConvertFrom-ReleaseTag {
    <#
    .SYNOPSIS
        Reads a release tag and returns its Module (the full name), Name (the
        short one) and Version, or nothing when the text is not a release tag.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Tag
    )

    if ($Tag -cnotmatch '^(?<name>[^/]+)/v(?<version>\d+\.\d+\.\d+)\z') {
        return
    }

    $name = $Matches['name']
    if (-not (Test-ShortModuleName -Name $name)) {
        return
    }

    return [PSCustomObject]@{
        Module  = "TaffarelJr.$name"
        Name    = $name
        Version = $Matches['version']
    }
}
