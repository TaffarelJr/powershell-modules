function Import-LocalModule {
    <#
    .SYNOPSIS
        Imports the one module that lives directly in a folder -
        its own .psd1 manifest if it has one, its bare .psm1 otherwise -
        without a caller needing to know the exact file name.
    .DESCRIPTION
        This repo's own modules keep <ModuleName> as both the folder name
        and the manifest's own base name, so a test file could just import
        the .psd1 directly - but a repo that keeps its modules as plain,
        unmanifested Helpers.psm1/Common-*.psm1 files has no such naming
        convention to rely on, and this covers that shape too, without a
        caller needing to know which shape a given folder turns out to be.

        Lives here, in TaffarelJr.TestRunner, rather than in
        TaffarelJr.RequiredModules: RequiredModules' whole domain is named,
        versioned, remote dependencies - is Pester >=5.0.0 installed, and if
        not, get it from the Gallery. This is the opposite kind of problem -
        an unnamed, unversioned, already-on-disk module a test file wants
        loaded - and its one motivating use is specifically running tests,
        which is this module's job, not RequiredModules'.

        Deliberately NOT recursive, and never a whole source tree at once -
        a caller passes the exact folder of the one thing it needs, the
        same way it would otherwise write out Import-Module. Importing
        every module under some larger root "just in case" would load
        things a given test file never asked for and never needed, for
        every single test file, which is real, unnecessary cost repeated
        across an entire run.

        A loose .ps1 alongside the module is left alone - unlike a .psm1,
        it isn't guaranteed to be safe to load just by sitting in the
        folder; it may be a real entry point with its own top-level
        parameters and side effects, not a function library.
    .PARAMETER Path
        The module's own folder - not a specific file inside it.
        Throws if neither a .psd1 nor a .psm1 lives there - a typo'd path
        should fail here, clearly, not surface later as some unrelated
        "command not found" once the test actually runs.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # -Global: this function's own caller is who needs the imported
    # module, not this module's own scope - without it, the import nests
    # inside this module's own session state instead, invisible to the
    # test file this was actually called on behalf of.
    $manifest = Get-ChildItem -LiteralPath $Path -Filter '*.psd1' | Select-Object -First 1
    if ($manifest) {
        Import-Module $manifest.FullName -Global -Force
        return
    }

    $module = Get-ChildItem -LiteralPath $Path -Filter '*.psm1' | Select-Object -First 1
    if ($module) {
        Import-Module $module.FullName -Global -Force
        return
    }

    throw "No .psd1 or .psm1 found directly under: $Path"
}
