#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
        'ConvertFrom-GitHubJson'
        'ConvertTo-GitHubFieldArgument'
        'ConvertTo-PascalCaseObject'
        'Invoke-GitHubApi'
        'Invoke-GitHubCommand'
        'Test-GitHubApi'
)