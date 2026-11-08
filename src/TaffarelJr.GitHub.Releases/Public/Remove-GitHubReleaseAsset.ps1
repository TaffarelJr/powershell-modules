using namespace System.Collections

function Remove-GitHubReleaseAsset {
    <#
    .SYNOPSIS
        Deletes one asset from a release.
    .DESCRIPTION
        Deletes without asking by default; -Confirm asks first.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Tag
        The release's tag, or a release object, read by its TagName and
        Repository - so a release from Get-GitHubRelease has its assets
        deleted in the repository it was read from.
    .PARAMETER Name
        The asset's file name, or an asset object, such as one of a
        release's Assets, read by its Name. Names and assets can be piped
        in; a release piped in instead throws.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form, as a URL, or as a
        repository object. Omit it to use the current directory's
        repository, or the -Tag release's own; given as $null, it throws.
        A -Tag release in a different repository than this throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        An asset's file name, or an asset object, bound to -Name. A piped
        asset's Repository binds to -Repository.
    .OUTPUTS
        None.
    .EXAMPLE
        Remove-GitHubReleaseAsset -Tag 'v1.0.0' -Name 'app.zip'

        Deletes the asset app.zip from the release tagged v1.0.0 of the
        current directory's repository.
    .EXAMPLE
        $release = Get-GitHubRelease -Tag 'v1.0.0' -Repository OWNER/REPO
        $release.Assets |
            Where-Object Name -Like '*.zip' |
            Remove-GitHubReleaseAsset -Tag $release

        Deletes the release's zip files, in OWNER/REPO.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Releases/README.md
    .LINK
        Add-GitHubReleaseAsset
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [object]$Tag,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline)]
        [object]$Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]$Repository
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

            $given = $PSBoundParameters.ContainsKey('Repository')
            Resolve-GitHubRepositoryArgument -Value $Repository -Given $given | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $reference = ConvertTo-GitHubReleaseReference -Release $Tag -Repository $Repository
            if ($Name -isnot [string] -and $Name -isnot [IDictionary] -and $Name -is [IEnumerable]) {
                throw "Give one asset at a time, not a list of $(@($Name).Count); pipe them to name several."
            }

            $asset = $Name
            if ($Name -isnot [string] -and $Name -isnot [ValueType]) {
                $values = @{}
                if ($Name -is [IDictionary]) {
                    foreach ($key in $Name.PSBase.Keys) {
                        $values["$key"] = $Name[$key]
                    }
                }
                else {
                    foreach ($property in $Name.PSObject.Properties) {
                        $values[$property.Name] = $property.Value
                    }
                }

                if ($values.ContainsKey('TagName')) {
                    throw 'A release was given as the asset: pipe its Assets instead, and give the release as -Tag.'
                }

                $asset = $values['Name']
                if ("$asset" -notmatch '\S') {
                    throw "An asset object needs a Name, and this one has none: $($Name.GetType().Name)."
                }
            }

            if ("$asset" -notmatch '\S') {
                throw "'$asset' is not an asset: give its file name, or an asset object."
            }

            $release = Format-GitHubReleaseTarget -Tag $reference.Tag -Repository $reference.Repository
            $shownAsset = Hide-UrlCredential -Text "$asset"
            if (-not $PSCmdlet.ShouldProcess("$release asset $shownAsset", 'Delete asset')) {
                return
            }

            $arguments = @('release', 'delete-asset', '--yes', '--', $reference.Tag, "$asset")
            $invocation = @{
                Activity   = "Deleting asset $asset from release $($reference.Tag)"
                Arguments  = $arguments
                Repository = $reference.Repository
            }
            Invoke-GitHubCommand @invocation | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
