function Test-GitHubActionsServerProcess {
    <#
    .SYNOPSIS
        Tells whether this PowerShell process was started as a server, whose
        standard output carries a session to another process.
    .DESCRIPTION
        Not exported. A background job, an out-of-process runspace, and SSH
        or named-pipe remoting each start pwsh with a server switch, such as
        -s, and talk to it over its standard output. Every runspace in such
        a process shares that output, a thread job or ForEach-Object
        -Parallel block among them, so a raw line from any of them breaks
        the session.

        The arguments are read as pwsh reads them: a switch may start with
        -, --, or /, may be shortened as far as pwsh allows, and the first
        switch it matches wins. Reading stops at -File, -Command, or the
        first argument that is no switch of pwsh's, which pwsh takes for the
        script - a path starting with / included - since what follows is the
        script's own. Some switches exist on Windows only.
    .PARAMETER Argument
        The process's arguments, without the program itself. Defaults to
        this process's own.
    .PARAMETER OnWindows
        Reads the switches pwsh has on Windows. Defaults to whether this is
        Windows.
    .OUTPUTS
        True if a server switch is among them.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyCollection()]
        [string[]]$Argument = @([Environment]::GetCommandLineArgs() | Select-Object -Skip 1),

        [bool]$OnWindows = $IsWindows
    )

    # pwsh's own switches in the order it tries them: name, shortest
    # accepted form, what follows, and whether it is a switch on Windows only.
    $switches = @(
        @('version', 'v', 'Stop'), @('help', 'h', 'Stop'), @('?', '?', 'Stop'), @('login', 'l', 'Flag'),
        @('noexit', 'noe', 'Flag'), @('noprofile', 'nop', 'Flag'), @('nologo', 'nol', 'Flag'),
        @('noninteractive', 'noni', 'Flag'), @('socketservermode', 'so', 'Server'),
        @('v2socketservermode', 'v2so', 'Server', 'Windows'), @('servermode', 's', 'Server'),
        @('namedpipeservermode', 'nam', 'Server'), @('sshservermode', 'sshs', 'Server'),
        @('noprofileloadtime', 'noprofileloadtime', 'Flag'), @('interactive', 'i', 'Flag'),
        @('configurationfile', 'configurationfile', 'Value'), @('configurationname', 'config', 'Value'),
        @('custompipename', 'cus', 'Value'), @('commandwithargs', 'commandwithargs', 'Stop'),
        @('cwa', 'cwa', 'Stop'), @('command', 'c', 'Stop'), @('windowstyle', 'w', 'Value'),
        @('file', 'f', 'Stop'), @('outputformat', 'o', 'Value'),
        @('of', 'o', 'Value'), @('inputformat', 'inp', 'Value'), @('if', 'if', 'Value'),
        @('executionpolicy', 'ex', 'Value'), @('ep', 'ep', 'Value'), @('encodedcommand', 'e', 'Value'),
        @('ec', 'e', 'Value'), @('encodedarguments', 'encodeda', 'Value'), @('ea', 'ea', 'Value'),
        @('settingsfile', 'settings', 'Value'), @('sta', 'sta', 'Flag'), @('mta', 'mta', 'Flag'),
        @('workingdirectory', 'wo', 'Value'), @('wd', 'wd', 'Value'),
        @('removeworkingdirectorytrailingcharacter', 'removeworkingdirectorytrailingcharacter', 'Flag', 'Windows'),
        @('token', 'to', 'Value', 'Windows'), @('utctimestamp', 'utc', 'Value', 'Windows')
    )

    for ($index = 0; $index -lt $Argument.Count; $index++) {
        $key = $Argument[$index].Trim()
        if (-not $key) {
            continue
        }

        if ($key[0] -notin '-', '/', [char]0x2013, [char]0x2014, [char]0x2015) {
            return $false
        }

        $first = $key[0]
        $key = $key.Substring(1)
        if ($key -and $first -ne '/' -and $key[0] -eq $first) {
            $key = $key.Substring(1)
        }

        $kind = 'Script'
        foreach ($switch in $switches) {
            if ($switch.Count -gt 3 -and -not $OnWindows) {
                continue
            }

            if ($key.Length -ge $switch[1].Length -and $switch[0].StartsWith($key, 'OrdinalIgnoreCase')) {
                $kind = $switch[2]
                break
            }
        }

        if ($kind -eq 'Server') {
            return $true
        }

        if ($kind -in 'Stop', 'Script') {
            return $false
        }

        if ($kind -eq 'Value') {
            $index++
        }
    }

    return $false
}
