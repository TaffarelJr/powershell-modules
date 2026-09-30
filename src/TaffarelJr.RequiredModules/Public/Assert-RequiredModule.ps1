using namespace System.Collections
using namespace System.Collections.Generic

function Assert-RequiredModule {
    <#
    .SYNOPSIS
        Makes sure every module a manifest names is installed at its minimum
        version, installing what is missing without a prompt, and throws if
        that cannot be done.
    .DESCRIPTION
        Meant for the top of a script, so the script finds what it needs
        wherever it runs, a developer's machine or CI alike. Each module that
        is missing or older than its minimum is installed with
        Install-RequiredModule, without asking anyone - for the current user,
        with Install-Module's -Force and -SkipPublisherCheck - and an
        "Installing ... done" line reports it. Then the module is looked up
        again: an install
        that fails, or that leaves the module not found or still too old,
        throws at once with the reason, the install command to run by hand
        and the documentation link, rather than let a later step fail without
        a cause.

        Install-RequiredModule only installs what is missing and returns; this
        also reads the manifests, checks the result, and fails when a
        requirement is still not met.

        Several manifests may be piped in. They are checked together once the
        last one has been read: a module named in more than one is checked
        once, at the highest minimum any of them asks for, and modules are
        handled in name order.

        This only checks and installs; it does not import. A module already
        loaded in this session counts, even one imported by its path and not
        on PSModulePath - so a new process, which does not have that module
        loaded, may still not find it. See Test-RequiredModule.

        -Confirm asks before each install, and so does a $ConfirmPreference of
        Medium or lower. A no skips that module, and every module skipped is
        named in one failure once the rest are done. Where no one can answer,
        such as a host started with -NonInteractive, the question fails
        instead. -Confirm:$false is the same as leaving it out.
        With -WhatIf each install is named in a 'What if:' line and does not
        count as a failure.
        With -WhatIf nothing is changed and nothing is returned.

        A manifest that cannot be read, an install that fails, and a
        requirement that is still not met are each a terminating error for
        the call, and in a pipeline they stop the pipeline.

        With -Verbose, shows the Install-Module command of each install.
    .PARAMETER Path
        The path to a manifest file: see Get-RequiredModule for its format.
        Binds from the FullName or PSPath of a piped file.
    .PARAMETER Data
        The manifest itself, in the same shape, when a caller builds it
        in code instead of maintaining a separate .psd1 file.
        Accepts pipeline input.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String. The path of a manifest file; or any object with a
        FullName, PSPath, or Path property, such as the files Get-ChildItem
        returns.

        System.Collections.IDictionary. A manifest built in code.
    .OUTPUTS
        None. A module that cannot be made available is an error.
    .EXAMPLE
        Assert-RequiredModule -Path ./RequiredModules.psd1
        Get-RequiredModule -Path ./RequiredModules.psd1 | Import-RequiredModule

        Installs whatever is missing, then imports the modules.
    .EXAMPLE
        @{ Pester = @{ MinimumVersion = '5.3.0' } } | Assert-RequiredModule

        Checks a manifest built in code.
    .EXAMPLE
        Get-ChildItem -Recurse -Filter RequiredModules.psd1 |
            Assert-RequiredModule

        Checks every manifest found below the current folder in one run.
    .EXAMPLE
        Assert-RequiredModule -Path ./RequiredModules.psd1 -Confirm

        Asks before installing each missing module, and fails naming every
        one said no to.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.RequiredModules/README.md
    .LINK
        Get-RequiredModule
    .LINK
        Install-RequiredModule
    .LINK
        Import-RequiredModule
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByData')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Shows text to the person at the console; it is not data.')]
    param(
        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'ByPath',
            ValueFromPipelineByPropertyName
        )]
        [Alias('FullName', 'PSPath')]
        [string]$Path,

        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'ByData',
            ValueFromPipeline
        )]
        [IDictionary]$Data
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $required = [Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            $modules = if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
                Get-RequiredModule -Path $Path
            }
            else {
                Get-RequiredModule -Data $Data
            }

            foreach ($module in $modules) {
                $known = $null
                if ($required.TryGetValue($module.Name, [ref]$known)) {
                    $isStricter = $null -ne $module.MinimumVersion -and
                    ($null -eq $known.MinimumVersion -or $module.MinimumVersion -gt $known.MinimumVersion)
                    if (-not $isStricter) {
                        continue
                    }
                }

                $required[$module.Name] = $module
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    end {
        try {
            $unsatisfied = [List[string]]::new()
            # PSBase: a module named Keys would otherwise be read in place of
            # every name.
            $names = @($required.PSBase.Keys | Sort-Object)
            foreach ($name in $names) {
                $module = $required[$name]
                $installed = Get-InstalledModuleVersion -Name $module.Name -MinimumVersion $module.MinimumVersion
                if (Test-MinimumVersion -InstalledVersion $installed -MinimumVersion $module.MinimumVersion) {
                    continue
                }

                $need = Get-ModuleRequirementText -Module $module
                if (-not $PSCmdlet.ShouldProcess($need, 'Install module')) {
                    if (-not $WhatIfPreference) {
                        $unsatisfied.Add($need)
                    }

                    continue
                }

                Write-Host "Installing $need ... " -NoNewline
                try {
                    Install-RequiredModule -Module $module -Confirm:$false
                }
                catch {
                    Write-Host 'failed'
                    $advice = Get-MissingModuleMessage -Module $module -InstalledVersion $installed
                    throw "Could not install ${need}: $($_.Exception.Message)`n$advice"
                }

                $found = Get-InstalledModuleVersion -Name $module.Name -MinimumVersion $module.MinimumVersion
                if (-not (Test-MinimumVersion -InstalledVersion $found -MinimumVersion $module.MinimumVersion)) {
                    Write-Host 'failed'
                    $result = if ($found) { "only $found is found" } else { 'is still not found' }
                    throw "$need was installed but $result - is the install location on PSModulePath?"
                }

                Write-Host 'done'
            }

            if ($unsatisfied.Count -gt 0) {
                throw "Required modules not satisfied: $($unsatisfied -join ', ')."
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
