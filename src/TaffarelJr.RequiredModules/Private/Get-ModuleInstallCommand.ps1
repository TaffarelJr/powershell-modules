using namespace System.Collections.Generic

function Get-ModuleInstallCommand {
    <#
    .SYNOPSIS
        Renders the Install-Module command line for one required module,
        for display in an error message.
    .DESCRIPTION
        Rendered from the same parameters Install-RequiredModule passes,
        so the command shown is the one that runs.
    .PARAMETER Module
        One result from Get-RequiredModule.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Module
    )

    process {
        $parameters = Get-ModuleInstallParameter -Module $Module
        $words = [List[string]]::new()
        $words.Add('Install-Module')
        foreach ($name in $parameters.PSBase.Keys) {
            $value = $parameters[$name]
            if ($value -is [bool]) {
                $words.Add("-$name")
            }
            else {
                $words.Add("-$name $value")
            }
        }

        return $words -join ' '
    }
}
