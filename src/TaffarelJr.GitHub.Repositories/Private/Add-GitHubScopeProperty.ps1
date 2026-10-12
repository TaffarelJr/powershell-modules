function Add-GitHubScopeProperty {
    <#
    .SYNOPSIS
        Writes each listed object back out with note properties saying
        where it was listed from.
    .DESCRIPTION
        gh's JSON for a secret, a variable, or a deploy key does not say
        which repository, environment, organization, or user it belongs
        to. The Get- function knows, so it attaches that here; the Set-
        and Remove- functions bind those properties by name, and a piped
        object is then acted on where it came from rather than in the
        current directory's repository. A Repository given as a URL that
        carries a credential is attached with the credential hidden: the
        object is printed, and gh ignores a URL's user information.
    .PARAMETER InputObject
        The listed objects.
    .PARAMETER Scope
        The properties to attach, in order, as name and value.
    .OUTPUTS
        Each object, with the properties added.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]]$InputObject,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$Scope
    )

    foreach ($item in $InputObject) {
        foreach ($name in $Scope.PSBase.Keys) {
            $value = $Scope[$name]
            if ($name -eq 'Repository' -and $value) {
                # The object is printed, and a caller may have named the repository by a URL carrying a token.
                $value = Hide-UrlCredential -Text "$value"
            }

            Add-Member -InputObject $item -NotePropertyName $name -NotePropertyValue $value -Force
        }

        $item
    }
}
