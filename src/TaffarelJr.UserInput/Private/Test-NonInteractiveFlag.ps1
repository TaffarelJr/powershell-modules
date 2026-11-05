function Test-NonInteractiveFlag {
    <#
    .SYNOPSIS
        Reports whether a PowerShell command line asked for -NonInteractive.
    .DESCRIPTION
        Not exported. PowerShell accepts any unambiguous start of an option's
        name, so -NonInteractive is also -NonI and -noni, and a launcher that
        types the short form is common. A dash or a slash may start an option.
        The options end at -Command, -File, or -EncodedCommand: what follows
        belongs to the script, whose own parameter might be called
        -NonInteractive, and says nothing about this session.
    .PARAMETER CommandLine
        The arguments this process was started with.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$CommandLine
    )

    foreach ($argument in $CommandLine) {
        if ($argument -notmatch '^[-/]{1,2}(?<name>[a-z]+)$') {
            continue
        }

        $name = $Matches['name']
        foreach ($scriptOption in 'command', 'commandwithargs', 'file', 'encodedcommand', 'ec') {
            if ($scriptOption.StartsWith($name, [StringComparison]::OrdinalIgnoreCase)) {
                return $false
            }
        }

        if ($name.Length -ge 3 -and 'noninteractive'.StartsWith($name, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}
