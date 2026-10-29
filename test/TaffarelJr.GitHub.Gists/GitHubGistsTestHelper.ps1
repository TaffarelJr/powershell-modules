# Shared by TaffarelJr.GitHub.Gists' own test files; the fake gh every
# GitHub module uses is in ../GitHubTestHelper.ps1.
function New-GistTestFolder {
    <#
    .SYNOPSIS
        Creates a new temporary folder holding the given files and folders,
        and returns its full path.
    .DESCRIPTION
        Not exported - a test-only fixture. A text is written exactly, as
        UTF-8 with no byte-order mark and no newline added; a byte array is
        written as those bytes. Delete the folder in the test's finally
        block.
    .PARAMETER File
        Each file to create: its path relative to the folder, and its
        content as a string or a byte array.
    .PARAMETER Folder
        Each empty folder to create, relative to the folder.
    .OUTPUTS
        The folder's full path.
    #>
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary]$File = @{},

        [string[]]$Folder = @()
    )

    $root = Join-Path ([System.IO.Path]::GetTempPath()) "gists-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $root | Out-Null
    foreach ($name in $Folder) {
        New-Item -ItemType Directory -Path (Join-Path $root $name) -Force | Out-Null
    }

    foreach ($name in $File.Keys) {
        $path = Join-Path $root $name
        $parent = Split-Path -Path $path -Parent
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $content = $File[$name]
        if ($content -is [byte[]]) {
            [System.IO.File]::WriteAllBytes($path, $content)
        }
        else {
            [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
        }
    }

    return $root
}

function Use-ReplacedFunction {
    <#
    .SYNOPSIS
        Replaces a function, or a cmdlet by the name, inside the imported
        Gists module, for the rest of the test file's process.
    .DESCRIPTION
        Not exported - a test-only fixture, for a value the file system or the
        session cannot hold on every platform, such as a file name with a
        colon in it. A function of the module's own script scope is found
        before any cmdlet or imported function of the same name, so the
        module's code calls the replacement.

        Nothing puts the original back, so a file that replaces a function
        does so after every case that needs the original.
    .PARAMETER Module
        The imported Gists module.
    .PARAMETER Name
        The name of the function to replace.
    .PARAMETER Body
        What the replacement does.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSModuleInfo]$Module,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Body
    )

    & $Module {
        param($Name, $Body)
        Set-Item -LiteralPath "Function:script:$Name" -Value $Body
    } $Name $Body
}
