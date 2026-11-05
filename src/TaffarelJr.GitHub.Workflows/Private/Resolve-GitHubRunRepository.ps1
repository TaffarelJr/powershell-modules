function Resolve-GitHubRunRepository {
    <#
    .SYNOPSIS
        Checks that a piped object is a workflow run, and returns the
        repository to act on it in.
    .DESCRIPTION
        Any object with a DatabaseId binds as a run id, so the piped object
        itself is read to make sure it is a run before gh acts on that id.
        A job, as Get-GitHubWorkflowRun reports one under Jobs, is known by
        its Steps or by a Url holding /job/; its DatabaseId is the job's
        own. Any other object with a Url is a run only when that Url is a
        run's - /actions/runs/ followed by the run id - so a release, an
        issue, or anything else that happens to carry a DatabaseId is
        refused. An object with no Url, and a plain id, pass. An object
        that bound no run id at all - where -RunId is optional, it binds
        only its Repository - is refused too.

        The repository then comes from Resolve-GitHubOriginRepository:
        -Repository, else the object's Repository, else the one in its Url.
    .PARAMETER InputObject
        The piped object, or $null when the run was given by parameter.
    .PARAMETER RunId
        The run id the object bound as; 0 when none was bound, and then
        any run's Url passes.
    .PARAMETER Repository
        The repository given, as text or a repository object; $null when
        none was.
    .PARAMETER Advice
        What to do instead of piping a job, ending that message.
    .PARAMETER Item
        What is acted on, for a repository mismatch's message. 'Workflow
        run <RunId>' when left out.
    .PARAMETER NoRun
        Says the call names no run at all - a job by its own id - so a
        piped object, a job included, is read only for its repository:
        it need not have a DatabaseId, and a job is not refused.
    .OUTPUTS
        The repository reference; nothing when none is known.
    .EXAMPLE
        $piped = if ($MyInvocation.ExpectingInput) { $_ } else { $null }
        $repository = Resolve-GitHubRunRepository -InputObject $piped `
            -RunId $RunId -Repository $Repository `
            -Advice 'Give the run it belongs to.'

        Gives 'o/r' for a run Get-GitHubWorkflowRun -Repository 'o/r'
        listed, and throws for a job or a release piped in.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$InputObject,

        [long]$RunId,

        [AllowNull()]
        [object]$Repository,

        [Parameter(Mandatory)]
        [string]$Advice,

        [string]$Item = "Workflow run $RunId",

        [switch]$NoRun
    )

    $url = ''
    $hasSteps = $false
    $isObject = $null -ne $InputObject -and $InputObject -isnot [string] -and $InputObject -isnot [ValueType]
    if ($isObject) {
        $url = "$($InputObject.PSObject.Properties['Url']?.Value)".Trim()
        $hasSteps = $null -ne $InputObject.PSObject.Properties['Steps']
    }

    if (-not $NoRun -and ($hasSteps -or $url -match '/job/')) {
        throw "A job is not a run: its DatabaseId is the job's own, not its run's. $Advice"
    }

    $advice = ' Give a run Get-GitHubWorkflowRun returned, or its DatabaseId.'
    if ($isObject -and $RunId -lt 1 -and -not $NoRun) {
        throw "The object piped in is not a workflow run: it has no DatabaseId.$advice"
    }

    $id = if ($RunId -gt 0 -and -not $NoRun) { "$RunId" } else { '\d+' }
    if ($url -and $url -notmatch "/actions/runs/$id(?:[/?#]|\z)") {
        $subject = if ($RunId -gt 0 -and -not $NoRun) { "workflow run $RunId" } else { 'a workflow run' }
        $shownUrl = Hide-UrlCredential -Text $url
        throw "The object piped in is not a workflow run: its Url '$shownUrl' is not $subject's.$advice"
    }

    return Resolve-GitHubOriginRepository -Repository $Repository -InputObject $InputObject -Url $url -Item $Item
}
