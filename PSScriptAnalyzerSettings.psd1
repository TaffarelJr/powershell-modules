@{
    # Used as: Invoke-ScriptAnalyzer -Path src -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
    # Every default rule runs except this one. A rule that only a few functions break is suppressed on
    # those functions, with a reason, instead of being turned off here.
    ExcludeRules = @(
        # Source files hold box-drawing characters and emoji. Every module requires PowerShell 7.4, whose
        # default, and the recommended encoding, is UTF-8 without a BOM; the rule is for Windows PowerShell 5.1.
        'PSUseBOMForUnicodeEncodedFile'
    )

    # Rules the analyzer ships switched off. Each one catches a mistake that is cheap to avoid.
    # PSUseConsistentParameterSetName stays off: in PSScriptAnalyzer 1.25.0 it throws a null-reference error when
    # one run analyzes several files (Close-OpenLine.ps1 with ConvertTo-CommandError.ps1 is enough). The
    # public-surface test requires a default parameter set wherever a command has several. The analyzer can
    # also throw the same error now and then with the rules below on, on files that pass when repeated: when
    # a run throws it, run it again, or analyze the files one at a time.
    Rules = @{
        PSUseSingleValueFromPipelineParameter = @{ Enable = $true }
        PSUseCorrectCasing                    = @{ Enable = $true }
        PSAvoidSemicolonsAsLineTerminators    = @{ Enable = $true }
        PSAvoidExclaimOperator                = @{ Enable = $true }
    }
}
