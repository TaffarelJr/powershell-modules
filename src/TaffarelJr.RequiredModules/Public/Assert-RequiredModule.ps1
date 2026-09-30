function Assert-RequiredModule {
    <#
    .SYNOPSIS
        Ensures every module in a manifest is installed,
        installing it if missing -
        interactively with a prompt, or failing clearly in CI.
    .DESCRIPTION
        Non-interactive: warns with the exact install command
        and documentation link, then throws -
        a CI log should never require someone to go digging for what to run.
        Interactive: prints the same message,
        then prompts before installing,
        so nothing installs onto a developer's machine without them saying yes.
    .PARAMETER Path
        The RequiredModules.psd1-style manifest. See Get-RequiredModule.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    foreach ($module in Get-RequiredModule -Path $Path) {
        if (Test-RequiredModule -Module $module) { continue }

        $message = Get-MissingModuleMessage -Module $module
        if (-not (Test-InteractiveHost)) {
            Write-Warning $message
            throw "$($module.Name) $($module.MinimumVersion) or later is required."
        }

        Write-Host $message
        if (-not (Confirm-Input -Prompt 'Install now?' -Default)) {
            throw "$($module.Name) $($module.MinimumVersion) or later is required."
        }

        Install-RequiredModule -Module $module
    }
}
