function Write-GitHubActionsCommand {
    <#
    .SYNOPSIS
        Writes one workflow command line to the log.
    .DESCRIPTION
        Not exported. The shape every logging command shares -
        Write-GitHubActionsDebug, -Notice, -Warning, -Error,
        Enter-GitHubActionsLogGroup, Exit-GitHubActionsLogGroup, and
        Hide-GitHubActionsValue all funnel through this; only the
        command name, properties, and data segment differ between them.
    .PARAMETER Command
        The command name, such as 'warning' or 'add-mask'.
    .PARAMETER Properties
        Key/value pairs rendered before the data segment. Omit for a
        command that takes none. A key whose value is empty is left out
        entirely, rather than rendered as 'key='.
    .PARAMETER Data
        The command's own payload, escaped and placed after the final
        '::'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [System.Collections.Specialized.OrderedDictionary]$Properties,

        [AllowEmptyString()]
        [string]$Data = ''
    )

    $line = "::$Command"
    if ($Properties -and $Properties.Count -gt 0) {
        $pairs = foreach ($key in $Properties.Keys) {
            $value = "$($Properties[$key])"
            if ($value) {
                "$key=$(ConvertTo-GitHubActionsCommandProperty -Value $value)"
            }
        }

        if ($pairs) {
            $line += ' ' + ($pairs -join ',')
        }
    }

    $line += "::$(ConvertTo-GitHubActionsCommandData -Value $Data)"
    Write-GitHubActionsLine -Line $line
}
