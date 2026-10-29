function Import-LocalModule {
    <#
    .SYNOPSIS
        Imports the one module that lives directly in a folder -
        the .psd1 or .psm1 named like the folder,
        else its lone .psd1 or .psm1 -
        without a caller needing to know the exact file name.
    .DESCRIPTION
        Deliberately NOT recursive, and never a whole source tree at once -
        a caller passes the exact folder of the one thing it needs, the
        same way it would otherwise write out Import-Module.

        The module file is chosen in this order: the .psd1 named like the
        folder, the .psm1 named like the folder, a lone .psd1, a lone .psm1.
        Anything else is ambiguous, and this throws, naming the files,
        rather than pick whichever sorts first. A lone .psd1 is taken as the
        module even when it is only a settings file, so a module that shares
        its folder with another .psd1 has to be named like the folder.

        A loose .ps1 alongside the module is left alone - unlike a .psm1,
        it isn't guaranteed to be safe to load just by sitting in the
        folder; it may be a real entry point with its own top-level
        parameters and side effects, not a function library.

        A folder with no module, or with more than one candidate, and a
        module that fails to import, are each a terminating error for the
        call.
    .PARAMETER Path
        The module's own folder - not a specific file inside it, which is
        refused. Throws if neither a .psd1 nor a .psm1 lives there - a typo'd
        path should fail here, clearly, not surface later as some unrelated
        "command not found" once the test actually runs.
    .INPUTS
        None. The folder is given with -Path.
    .OUTPUTS
        None. The module is imported into the global session.
    .EXAMPLE
        Import-LocalModule `
            -Path (Join-Path $PSScriptRoot '..' 'src' 'TaffarelJr.Tally')

        Imports TaffarelJr.Tally from a repository's own src/ folder, from a
        test file in the sibling test/ folder, whichever file shape it has.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestRunner/README.md
    .LINK
        Invoke-TestRun
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            throw "Not a module folder: $Path - pass the folder that holds the module's .psd1 or .psm1."
        }

        $folderName = (Get-Item -LiteralPath $Path).Name
        $manifests = @(Get-ChildItem -LiteralPath $Path -Filter '*.psd1' -File)
        $scripts = @(Get-ChildItem -LiteralPath $Path -Filter '*.psm1' -File)

        $named = @(
            $manifests | Where-Object { $_.BaseName -eq $folderName }
            $scripts | Where-Object { $_.BaseName -eq $folderName }
        )

        $chosen = if ($named) {
            $named[0]
        }
        elseif ($manifests.Count -eq 1) {
            $manifests[0]
        }
        elseif ($manifests.Count -eq 0 -and $scripts.Count -eq 1) {
            $scripts[0]
        }

        if (-not $chosen) {
            $found = @($manifests) + @($scripts)
            if (-not $found) {
                throw "No .psd1 or .psm1 found directly under: $Path"
            }

            throw "More than one module file under $Path, and none is named '$folderName': $($found.Name -join ', ')"
        }

        # -Global: this function's own caller is who needs the imported
        # module, not this module's own scope.
        Import-Module $chosen.FullName -Global -Force -ErrorAction Stop
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
