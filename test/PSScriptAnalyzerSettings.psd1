@{
    # Used as: Invoke-ScriptAnalyzer -Path test -Recurse -Settings ./test/PSScriptAnalyzerSettings.psd1
    # Tests break three rules on nearly every file, so they are off here; a rule that only a few files
    # break is suppressed in those files, with a reason, as in src.
    ExcludeRules = @(
        # Every test file's dividers are box-drawing characters, and the encoding is UTF-8 without a BOM
        # (see ../PSScriptAnalyzerSettings.psd1).
        'PSUseBOMForUnicodeEncodedFile'

        # Fixtures named New-... or Set-... build test data; they are not commands anyone runs with -WhatIf.
        'PSUseShouldProcessForStateChangingFunctions'

        # `Join-Path $root 'a' 'b'` reads better than the named form in a fixture, and tests are not published.
        'PSAvoidUsingPositionalParameters'
    )

    # The rules src switches on (see ../PSScriptAnalyzerSettings.psd1): tests meet the same standard.
    Rules = @{
        PSUseSingleValueFromPipelineParameter = @{ Enable = $true }
        PSUseCorrectCasing                    = @{ Enable = $true }
        PSAvoidSemicolonsAsLineTerminators    = @{ Enable = $true }
        PSAvoidExclaimOperator                = @{ Enable = $true }
    }
}
