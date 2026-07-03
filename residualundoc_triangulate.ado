*! version 1.0.0  Texas 2036 / Eric Booth  2026-07-02
*! residualundoc_triangulate: side-by-side residual-method comparison at a
*! single year. Handy for reporting the Pew/MPI/CMS 2023 range together with
*! your own workflow estimate.
*! -----------------------------------------------------------------------------
*! Syntax:
*!   residualundoc triangulate, YEar(#) SOurces(spec) [ WORKflow(#) SAve(fn) ]
*!
*! Sources spec is space-separated name=value pairs:
*!   sources(Pew=14000000 CMS=12244500 MPI=13738000)
*! Optionally add a WORKflow(#) value to display alongside the sources; this
*! is the estimate from your own -residualundoc interp- run.
*! -----------------------------------------------------------------------------

program define residualundoc_triangulate, rclass
    version 15.0

    syntax , YEar(int) SOurces(string) [ WORKflow(real -1e30) SAve(string) ]

    // Parse sources into two parallel locals.
    local names  ""
    local values ""
    local nS = 0
    local rest `"`sources'"'
    while `"`rest'"' != "" {
        gettoken tok rest : rest, parse(" ")
        local tok = strtrim(`"`tok'"')
        if `"`tok'"' == "" continue
        local eqpos = strpos(`"`tok'"', "=")
        if `eqpos' == 0 {
            di as err "sources() token '`tok'' must be name=value"
            exit 198
        }
        local nm = substr(`"`tok'"', 1, `eqpos' - 1)
        local vl = substr(`"`tok'"', `eqpos' + 1, .)
        local names  `"`names' `nm'"'
        local values `"`values' `vl'"'
        local ++nS
    }
    if `nS' < 2 {
        di as err "sources() must contain at least 2 name=value pairs"
        exit 198
    }

    // Print the triangulation.
    di _n as text "Residual-method estimates for " as result `year' as text ":"
    di as text "{hline 44}"
    di as text %-24s "Source" as text " " as text %14s "Estimate"
    di as text "{hline 44}"
    local vmin =  1e30
    local vmax = -1e30
    forvalues i = 1/`nS' {
        local nm : word `i' of `names'
        local vl : word `i' of `values'
        local vln = real("`vl'")
        di as result %-24s "`nm'" as text " " as result %14.0fc `vln'
        if `vln' < `vmin' local vmin = `vln'
        if `vln' > `vmax' local vmax = `vln'
    }
    if `workflow' > -1e29 {
        di as text "{hline 44}"
        di as result %-24s "This workflow" as text " " as result %14.0fc `workflow'
        // Whether the workflow value is in-range for the sources.
        local inrange = cond(`workflow' >= `vmin' - 1 & `workflow' <= `vmax' + 1, 1, 0)
        di as text "  " as text "in source range? " as result cond(`inrange', "yes", "no")
    }
    di as text "{hline 44}"
    di as text "spread across sources: " as result %5.2f 100 * (`vmax' / `vmin' - 1) ///
        as text " percent"

    return scalar year        = `year'
    return scalar N_sources   = `nS'
    return scalar min         = `vmin'
    return scalar max         = `vmax'
    return scalar spread_pct  = 100 * (`vmax' / `vmin' - 1)
    return local  sources      `"`names'"'
    return local  values       `"`values'"'
    if `workflow' > -1e29 return scalar workflow = `workflow'

    if "`save'" != "" {
        preserve
            clear
            local N = `nS' + cond(`workflow' > -1e29, 1, 0)
            quietly set obs `N'
            quietly gen str32 source = ""
            quietly gen int   year   = `year'
            quietly gen double value = .
            forvalues i = 1/`nS' {
                local nm : word `i' of `names'
                local vl : word `i' of `values'
                quietly replace source = "`nm'" in `i'
                quietly replace value  = `vl'  in `i'
            }
            if `workflow' > -1e29 {
                quietly replace source = "This workflow" in `=`nS' + 1'
                quietly replace value  = `workflow'      in `=`nS' + 1'
            }
            local savefile : word 1 of `save'
            local savefile = subinstr(`"`savefile'"', ",", "", .)
            capture export delimited using `save'
            if _rc quietly save `save'
        restore
    }
end
