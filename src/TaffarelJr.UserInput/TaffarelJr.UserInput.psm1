#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($required in 'TaffarelJr.ConsoleOutput') {
    $loaded = Get-Module -Name $required
    if (-not $loaded) {
        throw "$required must be loaded before TaffarelJr.UserInput."
    }

    Import-Module -ModuleInfo $loaded -ErrorAction Stop
}

$script:CiVariableName = @(
    'CI'
    'GITHUB_ACTIONS'
    'TF_BUILD'
    'GITLAB_CI'
    'JENKINS_URL'
    'TEAMCITY_VERSION'
    'BUILDKITE'
    'CIRCLECI'
    'APPVEYOR'
    'TRAVIS'
)

$script:CallMistakeErrorId = @(
    'RequirementWithoutPattern,Assert-Input'
    'InvalidPattern,Assert-Input'
    'ValidateReturnedBoolean,Assert-Input'
    'ValidateReturnedNonString,Assert-Input'
    'ChoiceDuplicated,Assert-Input'
    'EndOfInput'
    'DefaultNotAnOption,Select-Choice'
    'OptionPadded,Select-Choice'
    'OptionDuplicated,Select-Choice'
)

$script:MistypedBindingErrorId = @(
    'NamedParameterNotFound'
    'AmbiguousParameter'
    'AmbiguousParameterSet'
    'MissingMandatoryParameter'
    'MissingArgument'
    'PositionalParameterNotFound'
    'ParameterAlreadyBound'
)

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Assert-Input'
    'Confirm-Input'
    'Confirm-Proceed'
    'Get-EnvironmentVariable'
    'Invoke-InputRetry'
    'Read-Input'
    'Read-Secret'
    'Select-Choice'
    'Set-EnvironmentVariable'
    'Test-InteractiveHost'
    'Wait-KeyPress'
)
