function Find-NativeCommand {
    <#
    .SYNOPSIS
        Returns the command a name or path stands for, with a wildcard
        character in it taken as part of the name.
    .DESCRIPTION
        Not exported. Get-Command has no literal form: it runs a file that
        has the exact name, and matches the name as a pattern only when none
        does, so 'Get-Dat*' would find Get-Date, and a path ending in '*'
        would find some other program in the folder. A name holding a
        wildcard character therefore counts only for a command of exactly
        that name, or a file at exactly that path.
    .PARAMETER Command
        The name or path, as the caller gave it.
    .PARAMETER ApplicationOnly
        Looks only for an executable: not a function, alias, cmdlet, or
        script.
    .OUTPUTS
        The first command found, as Get-Command returns it; nothing when
        there is none.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [switch]$ApplicationOnly
    )

    $lookup = @{
        Name        = $Command
        ErrorAction = 'Ignore'
    }

    if ($ApplicationOnly) {
        $lookup.CommandType = 'Application'
    }

    $found = @(Get-Command @lookup)
    if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Command)) {
        $literal = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Command)
        $found = @($found | Where-Object { $_.Name -eq $Command -or $_.Source -eq $literal })
    }

    return $found | Select-Object -First 1
}
