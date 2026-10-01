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

        -WhatIf and -Confirm name the variable and each scope, User and
        Process, on its own, never the value. On a non-Windows platform only
        Process is named, as the User write is not attempted there.
        With -WhatIf nothing is changed and nothing is returned.

        A write that fails is a terminating error for the call, and in a
        pipeline it stops the pipeline.
    .PARAMETER Name
        The environment variable to write. A blank name, one that starts with
        a space, or one that contains '=' is refused before anything is
        written. Binds from a piped object's Name property.
    .PARAMETER Value
        The value to persist: text, a number or a boolean as its text, or an
        object whose Value property holds it. An object with no Value
        property is refused rather than written as its own text. Empty, or
        $null, removes the variable, in both places.
        It is stored as plain text in the User settings, readable by every
        program that user runs - so a secret kept this way is only as safe as
        the account.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object. The value to write, such as a string; or any object
        with a Name and a Value property.
    .OUTPUTS
        None. The variable is written.
    .EXAMPLE
        $token = Read-Secret -Prompt 'Token'
        if ($token) { $token | Set-EnvironmentVariable -Name 'MY_TOKEN' }

        An empty answer is not saved: an empty value would remove the variable.
    .EXAMPLE
        Set-EnvironmentVariable -Name 'REPO_NAME' -Value 'my-repo' -WhatIf

        Names the variable it would write, in each scope, and changes nothing.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/README.md
    .LINK
        Get-EnvironmentVariable
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidatePattern(
            '^[^=\s][^=]*\z',
            ErrorMessage = "Environment variable name '{0}' must not be blank, start with a space, or contain '='")]
        [string]$Name,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            $text = Resolve-EnvironmentValue -InputObject $Value
            $action = if ($text) { 'Set environment variable' } else { 'Remove environment variable' }
            if ($IsWindows -and $PSCmdlet.ShouldProcess("$Name (User)", $action)) {
                Set-EnvironmentValue -Name $Name -Value $text -Target User
            }

            if ($PSCmdlet.ShouldProcess("$Name (Process)", $action)) {
                Set-EnvironmentValue -Name $Name -Value $text -Target Process
                if (-not $IsWindows) {
                    Write-Detail 'This only persists for the current session on this platform'
                    Write-Detail 'To keep it for later sessions, add this to your shell profile:'
                    Write-Detail "  export $Name=..."
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
