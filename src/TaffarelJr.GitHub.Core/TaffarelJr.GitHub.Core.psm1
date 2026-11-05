#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($required in 'TaffarelJr.ProcessInvocation') {
    $loaded = Get-Module -Name $required
    if (-not $loaded) {
        throw "$required must be loaded before TaffarelJr.GitHub.Core."
    }

    Import-Module -ModuleInfo $loaded -ErrorAction Stop
}

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Assert-GitHubHostname'
    'Assert-GitHubPollRead'
    'Assert-GitHubSameRepository'
    'ConvertFrom-GitHubJson'
    'ConvertTo-GitHubCsvField'
    'ConvertTo-GitHubFieldArgument'
    'ConvertTo-GitHubJsonFieldList'
    'ConvertTo-GitHubRepositoryReference'
    'ConvertTo-PascalCaseObject'
    'Format-GitHubRepositoryName'
    'Get-GitHubTimeoutMessage'
    'Invoke-GitHubApi'
    'Invoke-GitHubCommand'
    'New-GitHubPoll'
    'Resolve-GitHubInputFile'
    'Resolve-GitHubItemReference'
    'Resolve-GitHubPath'
    'Resolve-GitHubRepositoryArgument'
    'Test-GitHubApi'
    'Test-GitHubPollExpired'
    'Use-GitHubTextFile'
    'Wait-GitHubPoll'
)
