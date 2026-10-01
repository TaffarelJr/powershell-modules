function Set-EnvironmentVariable {
    <#
    .SYNOPSIS
        Writes an environment variable so a later run will not ask again.
    .DESCRIPTION
        Writes both the User-scope value (outlives this process)
        and the current process's own copy
        (so the rest of this run sees it too,
        without having to start a new process first).
        There is no plain this-process-only counterpart to this function -
        $env:Name = $Value already does that.

        On a non-Windows platform,
        [Environment]::SetEnvironmentVariable's User/Machine targets
        are a silent no-op - only the current-process write takes effect there,
        so this prints a reminder of the shell command
        that would make it persist instead,
        rather than silently doing less than its name promises.
        The value itself is never echoed,
        even when it is not actually a secret -
        this function has no way to tell the difference,
        so it treats every value as something that
        should not land in a terminal or a log.
    .PARAMETER Name
        The environment variable to write.
    .PARAMETER Value
        The value to persist.
    .EXAMPLE
        Read-Secret -Prompt 'Token' | Set-EnvironmentVariable -Name 'MY_TOKEN'
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [string]$Value
    )

    process {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        [Environment]::SetEnvironmentVariable($Name, $Value)

        if (-not $IsWindows) {
            Write-Detail 'This only persists for the current session on this platform'
            Write-Detail 'To keep it for later sessions, add this to your shell profile:'
            Write-Detail "  export $Name=..."
        }
    }
}
