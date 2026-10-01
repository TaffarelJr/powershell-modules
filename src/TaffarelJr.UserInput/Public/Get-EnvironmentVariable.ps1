function Get-EnvironmentVariable {
    <#
    .SYNOPSIS
        Returns an environment variable's value, or $null if it is unset.
    .DESCRIPTION
        Trimmed, with a whitespace-only value treated the same as unset -
        a variable holding only spaces is not meaningfully "set"
        to a caller deciding whether to prompt instead.
    .PARAMETER Name
        The environment variable to read.
    .EXAMPLE
        $name = Get-EnvironmentVariable -Name 'REPO_NAME'
        if (-not $name) { $name = Read-Input -Prompt 'Repo name' }
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return $value.Trim()
}
