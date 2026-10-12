using namespace System.Collections

function ConvertTo-GitHubWorkflowReference {
    <#
    .SYNOPSIS
        Returns the workflow id, name, or file name gh takes, from any of
        those or from a workflow or run object.
    .DESCRIPTION
        An object is read by its numeric Id first - a workflow's own
        number, which gh always resolves, where the Path of a dynamic
        workflow such as dynamic/dependabot/dependabot-updates matches
        nothing gh looks up - then by its Path, then by the
        WorkflowDatabaseId a run carries. An empty value is passed over
        for the next. A hashtable is read by those keys, in any case.

        A parameter that takes both a value and an object by pipeline must
        be an [object]: as a [string], PowerShell turns a piped object into
        its text ("@{DatabaseId=...}") instead of reading it.
    .PARAMETER Workflow
        A workflow id, name, or file name, or a workflow or run object.
        $null throws: a lookup that came back empty must not mean every
        workflow. A collection of one, as @() makes of a lookup, is read
        as its element; a longer one throws.
    .PARAMETER NotPiped
        Says the caller's -Workflow does not take pipeline input, so the
        message for a list says to call once per workflow rather than to
        pipe them.
    .OUTPUTS
        The reference, trimmed.
    .EXAMPLE
        $reference = ConvertTo-GitHubWorkflowReference -Workflow $workflow

        Gives '132478870' for the Dependabot Updates workflow object
        Get-GitHubWorkflow returned, and 'ci.yml' for the text 'ci.yml'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Workflow,

        [switch]$NotPiped
    )

    $isList = $Workflow -isnot [string] -and $Workflow -isnot [IDictionary] -and $Workflow -is [IEnumerable]
    if ($isList -and @($Workflow).Count -eq 0) {
        throw 'Give one workflow, not an empty list.'
    }

    if ($isList -and @($Workflow).Count -eq 1) {
        $Workflow = @($Workflow)[0]
        $isList = $Workflow -isnot [string] -and $Workflow -isnot [IDictionary] -and $Workflow -is [IEnumerable]
    }

    if ($null -eq $Workflow) {
        throw 'A workflow was given, but it is $null.'
    }

    if ($Workflow -is [bool] -or $Workflow -is [switch]) {
        throw "'$Workflow' is not a workflow: give its id, name, or file name, or a workflow object."
    }

    if ($isList) {
        $advice = if ($NotPiped) { '; call once per workflow.' } else { '; pipe them to name several.' }
        throw "Give one workflow at a time, not a list of $(@($Workflow).Count)$advice"
    }

    $reference = $Workflow
    if ($Workflow -isnot [string] -and $Workflow -isnot [ValueType]) {
        $values = @{}
        if ($Workflow -is [IDictionary]) {
            foreach ($key in $Workflow.PSBase.Keys) {
                $values["$key"] = $Workflow[$key]
            }
        }
        else {
            foreach ($property in $Workflow.PSObject.Properties) {
                $values[$property.Name] = $property.Value
            }
        }

        $reference = $null
        $patterns = [ordered]@{
            Id                 = '^\d+$'
            Path               = '\S'
            WorkflowDatabaseId = '^\d+$'
        }
        foreach ($name in $patterns.Keys) {
            if ("$($values[$name])".Trim() -match $patterns[$name]) {
                $reference = $values[$name]
                break
            }
        }

        if ($null -eq $reference) {
            throw 'A workflow object needs an Id, a Path, or a WorkflowDatabaseId, and this one has none:' +
            " $($Workflow.GetType().Name)."
        }
    }

    $text = "$reference".Trim()
    if (-not $text) {
        throw "'$reference' is not a workflow: give its id, name, or file name, or a workflow object."
    }

    return $text
}
