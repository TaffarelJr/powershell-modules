function Get-TestCaller {
    <#
    .SYNOPSIS
        Returns where in the test file an assertion was made, as
        " [File.ps1:42]", or an empty string when it was not made from a file.
    .DESCRIPTION
        Not exported. The first call-stack frame in a *.Tests.ps1 file, so
        an assertion made inside a shared helper file still reports the
        line of the case that called it. Without one, the first frame
        outside this module's own folder, so an assertion built on another
        one still reports the line that made it, not the line in the kit.
    .PARAMETER CallStack
        The frames to look through, innermost first. Callers leave it out,
        for the current call stack; a test gives frames of its own.
    #>
    param(
        [AllowEmptyCollection()]
        [object[]]$CallStack = (Get-PSCallStack)
    )

    $moduleFolder = $MyInvocation.MyCommand.Module.ModuleBase + [IO.Path]::DirectorySeparatorChar
    $outside = $null
    foreach ($frame in $CallStack) {
        $script = $frame.ScriptName
        if (-not $script -or $script.StartsWith($moduleFolder, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if ($script.EndsWith('.Tests.ps1', [StringComparison]::OrdinalIgnoreCase)) {
            return " [$(Split-Path -Leaf $script):$($frame.ScriptLineNumber)]"
        }

        if ($null -eq $outside) {
            $outside = $frame
        }
    }

    if ($null -eq $outside) {
        return ''
    }

    return " [$(Split-Path -Leaf $outside.ScriptName):$($outside.ScriptLineNumber)]"
}
