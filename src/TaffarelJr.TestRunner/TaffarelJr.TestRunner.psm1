#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($required in
    'TaffarelJr.Tally',
    'TaffarelJr.ConsoleOutput',
    'TaffarelJr.ProcessInvocation',
    'TaffarelJr.RequiredModules'
) {
    $loaded = Get-Module -Name $required
    if (-not $loaded) {
        throw "$required must be loaded before TaffarelJr.TestRunner."
    }

    Import-Module -ModuleInfo $loaded -ErrorAction Stop
}

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Import-LocalModule'
    'Invoke-TestFileProcess'
    'Invoke-TestRun'
)
