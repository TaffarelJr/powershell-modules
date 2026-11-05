function Hide-UrlCredential {
    <#
    .SYNOPSIS
        Returns text with every credential a URL in it carries replaced by
        ***.
    .DESCRIPTION
        For text a person reads - a message, a -WhatIf target, a command
        line - that may hold a URL a caller gave, as in
        https://x-access-token:<token>@github.com/o/r: the user information
        of such a URL is replaced by ***, and everything else is kept as it
        is. Every failure message of TaffarelJr.ProcessInvocation runs each
        piece of text it shows - the activity, each word of the command
        line, each line the command printed, a path - through here.

        A credential is:
        - USER:PASSWORD@, with or without a scheme in front: from the start
          of the user name to the last @ before the next ://, so the
          password may hold @, /, :, %, #, ?, brackets, or spaces, and the
          user name an @ (an e-mail address), brackets, digits, spaces, or
          colons (the first colon is read as the start of the password, and
          both are hidden);
        - after ://, a user name or token alone, up to the last @ before
          the first slash or colon;
        - in text without a scheme, a user name or token alone whose @ a
          host and a slash follow, as in TOKEN@HOST/OWNER/REPO. The SSH
          form's user, as in git@HOST:OWNER/REPO, is not a credential and
          is kept.
        Hiding errs toward hiding too much: an @ later in the text, such as
        in a path after a credential, after HOST:PORT, or in an e-mail
        address after any colon, hides everything up to it too, which
        leaves that part unreadable but shows no secret. Not hidden whole:
        a password holding ://, a user name holding a slash, and, without a
        scheme, a user name alone that holds whitespace. A token in a query
        string (?access_token=...) is not user information and is not
        hidden.

        The text is read as one, line breaks included, so an @ on a later
        line can hide earlier ones; pipe several lines in to hide each on
        its own. The time taken grows with the length of the text, never
        with its square, so a long line of output is cheap to hide.
        Hiding what it returns gives the same text back.
    .PARAMETER Text
        The text to hide credentials in. $null and empty text give empty
        text.
    .INPUTS
        System.String. The text, one string at a time.
    .OUTPUTS
        System.String. The text, with every credential replaced by ***.
    .EXAMPLE
        Hide-UrlCredential -Text 'Cloning https://u:ghs_abc@github.com/o/r'

        Returns 'Cloning https://***@github.com/o/r'.
    .EXAMPLE
        $shown = @($result.ErrorOutput | Hide-UrlCredential) -join "`n"

        Hides credentials in each line of a command's error output on its
        own, so an @ on one line cannot hide the lines before it.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ProcessInvocation/README.md
    .LINK
        Invoke-NativeCommand
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            # Every credential ends in an @.
            $lastAt = $Text.LastIndexOf([char]'@')
            if ($lastAt -lt 0) {
                return $Text
            }

            # The rules, as one regular expression, are
            #   (?s)[^/:]*:(?!//)(?:(?!://).)*@
            #   | (?<=://)[^/:]+@
            #   | (?<![^\s,;])[^\s/:]+@(?=(?:\[[^\]\s]*\]|[^\s/:@\[]+)(?::\d+)?/)
            # which a regex engine runs in time quadratic in the text. The tables
            # below answer each branch at a position in constant time instead.
            $chars = $Text.ToCharArray()
            $count = $chars.Length
            $isScheme = [bool[]]::new($count + 1)
            $scheme = $Text.IndexOf('://', [StringComparison]::Ordinal)
            while ($scheme -ge 0) {
                $isScheme[$scheme] = $true
                $scheme = $Text.IndexOf('://', $scheme + 1, [StringComparison]::Ordinal)
            }

            $nextScheme = [int[]]::new($count + 1)
            $nextSeparator = [int[]]::new($count + 1)
            $nextTokenEnd = [int[]]::new($count + 1)
            $nextScheme[$count] = $count
            $nextSeparator[$count] = $count
            $nextTokenEnd[$count] = $count
            for ($index = $count - 1; $index -ge 0; $index--) {
                $char = $chars[$index]
                $separator = $char -ceq '/' -or $char -ceq ':'
                $nextScheme[$index] = if ($isScheme[$index]) { $index } else { $nextScheme[$index + 1] }
                $nextSeparator[$index] = if ($separator) { $index } else { $nextSeparator[$index + 1] }
                $tokenEnd = $separator -or [char]::IsWhiteSpace($char)
                $nextTokenEnd[$index] = if ($tokenEnd) { $index } else { $nextTokenEnd[$index + 1] }
            }

            $previousAt = [int[]]::new($count + 1)
            $previousHostAt = [int[]]::new($count + 1)
            $previousAt[0] = -1
            $previousHostAt[0] = -1
            for ($index = 0; $index -lt $count; $index++) {
                $previousAt[$index + 1] = $previousAt[$index]
                $previousHostAt[$index + 1] = $previousHostAt[$index]
                if ($chars[$index] -cne '@') {
                    continue
                }

                $previousAt[$index + 1] = $index
                $start = $index + 1
                $hostEnd = $start
                if ($start -lt $count -and $chars[$start] -ceq '[') {
                    $hostEnd = $start + 1
                    while ($hostEnd -lt $count -and $chars[$hostEnd] -cne ']' -and
                        -not [char]::IsWhiteSpace($chars[$hostEnd])) {
                        $hostEnd++
                    }

                    if ($hostEnd -ge $count -or $chars[$hostEnd] -cne ']') {
                        continue
                    }

                    $hostEnd++
                }
                else {
                    while ($hostEnd -lt $count -and -not [char]::IsWhiteSpace($chars[$hostEnd]) -and
                        $chars[$hostEnd] -cnotin '/', ':', '@', '[') {
                        $hostEnd++
                    }

                    if ($hostEnd -eq $start) {
                        continue
                    }
                }

                $slash = $hostEnd
                if ($slash -lt $count -and $chars[$slash] -ceq ':') {
                    $slash++
                    while ($slash -lt $count -and [char]::IsDigit($chars[$slash])) {
                        $slash++
                    }

                    if ($slash -eq $hostEnd + 1) {
                        continue
                    }
                }

                if ($slash -lt $count -and $chars[$slash] -ceq '/') {
                    $previousHostAt[$index + 1] = $index
                }
            }

            $shown = [System.Text.StringBuilder]::new($count)
            $kept = 0
            $start = 0
            while ($start -lt $lastAt) {
                $end = -1
                $colon = $nextSeparator[$start]
                if ($colon -lt $count -and $chars[$colon] -ceq ':' -and -not $isScheme[$colon]) {
                    $at = $previousAt[$nextScheme[$colon + 1]]
                    if ($at -gt $colon) {
                        $end = $at
                    }
                }

                if ($end -lt 0 -and $start -ge 3 -and $isScheme[$start - 3]) {
                    $at = $previousAt[$colon]
                    if ($at -gt $start) {
                        $end = $at
                    }
                }

                if ($end -lt 0 -and ($start -eq 0 -or [char]::IsWhiteSpace($chars[$start - 1]) -or
                        $chars[$start - 1] -cin ',', ';')) {
                    $at = $previousHostAt[$nextTokenEnd[$start]]
                    if ($at -gt $start) {
                        $end = $at
                    }
                }

                if ($end -lt 0) {
                    $start++
                    continue
                }

                $shown.Append($Text, $kept, $start - $kept).Append('***@') | Out-Null
                $kept = $end + 1
                $start = $kept
            }

            return $shown.Append($Text, $kept, $count - $kept).ToString()
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
