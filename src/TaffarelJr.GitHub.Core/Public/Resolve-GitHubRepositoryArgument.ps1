function Resolve-GitHubRepositoryArgument {
    <#
    .SYNOPSIS
        Returns the reference gh takes for a function's optional repository
        parameter, nothing when it was left out, and throws when it was
        given as $null.
    .DESCRIPTION
        Leaving the parameter out means the current directory's
        repository. Giving it as $null - a lookup or a filter that found
        nothing, or any list holding only $null, such as @($lookup) or a
        HashSet - is a
        mistake, and acting on whatever clone the caller stands in would
        hide it, so that throws.

        A value is read by ConvertTo-GitHubRepositoryReference: OWNER/REPO,
        HOST/OWNER/REPO, a URL, or a repository object, with -Name passed on,
        so a blank one throws "-<Name> is blank: ...".

        Call it once, in begin, for the value given on the command line: a
        piped object whose Repository is $null means "the current
        directory's", which is a different thing from a caller who named
        -Repository and got nothing.
    .PARAMETER Value
        The parameter's value.
    .PARAMETER Given
        Whether the caller bound the parameter at all, as its
        $PSBoundParameters.ContainsKey says.
    .PARAMETER Name
        The parameter's name without its dash, for the message. Repository
        when left out.
    .PARAMETER Omitted
        What leaving the parameter out means, for the message. The current
        directory's repository when left out.
    .INPUTS
        None
    .OUTPUTS
        System.String
        The reference; nothing when the parameter was left out.
    .EXAMPLE
        $given = $PSBoundParameters.ContainsKey('Repository')
        $reference = Resolve-GitHubRepositoryArgument -Value $Repository `
            -Given $given

        Gives 'o/r' for -Repository 'o/r', nothing when -Repository was
        left out, and throws "-Repository was given, but it is $null -
        leave it out to use the current directory's repository." for
        -Repository $null.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [bool]$Given,

        [ValidatePattern('^\w+\z', ErrorMessage = "'{0}' is not a parameter name: give it without its dash.")]
        [string]$Name = 'Repository',

        [ValidatePattern(
            '\S',
            ErrorMessage = '-Omitted is blank: give what leaving the parameter out means, or leave it out.')]
        [string]$Omitted = "the current directory's repository"
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $Given) {
            return
        }

        $onlyNull = $false
        if ($Value -isnot [string] -and $Value -isnot [System.Collections.IDictionary] -and
            $Value -is [System.Collections.IEnumerable]) {
            $items = @($Value)
            $onlyNull = $items.Count -gt 0 -and @($items | Where-Object { $null -ne $_ }).Count -eq 0
        }
        if ($null -eq $Value -or $onlyNull) {
            throw "-$Name was given, but it is `$null - leave it out to use $(Hide-UrlCredential -Text $Omitted)."
        }

        return ConvertTo-GitHubRepositoryReference -Repository $Value -Name $Name
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
