*! version 1.0.0  Texas 2036 / Eric Booth  2026-07-02
*! residualundoc_interp: anchor-interpolation implementation of the residual
*! method for estimating the undocumented population.
*! -----------------------------------------------------------------------------
*! Given survey-measured noncitizens C_t and one or more published residual-
*! method anchor values U_a at anchor years {a}, the estimator sets
*!   theta_a = U_a / C_a
*! at each anchor year a and interpolates theta between anchors. The estimated
*! undocumented population is
*!   U_hat_t = theta_t * C_t.
*! This reproduces published residual-method values exactly at anchor years and
*! uses ACS noncitizen movement to fill years between and beyond anchors. See
*! Warren, Warren & Zheng (2023) for the underlying residual identity.
*!
*! Syntax:
*!   residualundoc interp yearvar noncitizensvar [if] [in],
*!       ANCHors(spec) [ SOURCEname(name) POP(varname)
*!                       INTerpolate(linear|logit|nearest)
*!                       TAils(flat|linear|missing) GENerate(prefix) REPlace ]
*!
*! Anchor spec grammar (space-separated year=value pairs; use SOURCEname() to
*! label the series):
*!    anchors(2010=11400000 2015=11000000 2023=14000000)
*!
*! For panel data with multiple groups, run once per group with -if- or use
*! -bysort group: residualundoc interp ...-.
*! -----------------------------------------------------------------------------

program define residualundoc_interp, rclass byable(recall)
    version 15.0

    syntax varlist(min=2 max=2 numeric) [if] [in] , ///
        ANCHors(string)                             ///
        [ SOURCEname(string) POP(varname numeric)   ///
          INTerpolate(name) TAils(name)             ///
          GENerate(string) REPlace ]

    tokenize `varlist'
    local yearvar `1'
    local ncvar   `2'

    if "`interpolate'" == "" local interpolate "linear"
    if "`tails'" == ""       local tails "flat"
    if "`generate'" == ""    local generate "u_"
    if "`sourcename'" == ""  local sourcename "anchor"

    if !inlist("`interpolate'", "linear", "logit", "nearest") {
        di as err "interpolate() must be linear, logit, or nearest"
        exit 198
    }
    if !inlist("`tails'", "flat", "linear", "missing") {
        di as err "tails() must be flat, linear, or missing"
        exit 198
    }

    // ---- Parse anchors into two same-length local lists: years_ and values_.
    local years_  ""
    local values_ ""
    local nA = 0
    local rest `"`anchors'"'
    while `"`rest'"' != "" {
        gettoken tok rest : rest, parse(" ")
        local tok = strtrim(`"`tok'"')
        if `"`tok'"' == "" continue
        local eqpos = strpos(`"`tok'"', "=")
        if `eqpos' == 0 {
            di as err "anchors() token '`tok'' must be year=value"
            exit 198
        }
        local yr = substr(`"`tok'"', 1, `eqpos' - 1)
        local vl = substr(`"`tok'"', `eqpos' + 1, .)
        capture confirm number `yr'
        if _rc {
            di as err "anchors() token '`tok'' has non-numeric year"
            exit 198
        }
        capture confirm number `vl'
        if _rc {
            di as err "anchors() token '`tok'' has non-numeric value"
            exit 198
        }
        local years_  "`years_' `yr'"
        local values_ "`values_' `vl'"
        local ++nA
    }
    if `nA' == 0 {
        di as err "anchors() must contain at least one year=value pair"
        exit 198
    }

    // ---- Build variable list under a temporary touse; drop existing outputs.
    foreach suf in theta undoc lawful published at_anchor pct_pop {
        capture confirm variable `generate'`suf'
        if !_rc {
            if "`replace'" == "" {
                di as err "`generate'`suf' exists; use -replace-"
                exit 110
            }
            drop `generate'`suf'
        }
    }
    marksample touse

    // ---- Place published anchor values on their years.
    quietly gen double `generate'published = .
    quietly gen byte   `generate'at_anchor = 0
    forvalues i = 1/`nA' {
        local yv : word `i' of `years_'
        local pv : word `i' of `values_'
        quietly replace `generate'published = `pv' ///
            if `touse' & `yearvar' == `yv'
        quietly replace `generate'at_anchor = 1 ///
            if `touse' & `yearvar' == `yv'
    }

    // ---- Compute theta at anchor rows.
    tempvar theta_a
    quietly gen double `theta_a' = `generate'published / `ncvar' if `touse'

    // ---- Interpolate theta across all touse rows.
    quietly gen double `generate'theta = .

    // Preserve original row order via -sortkey- so we return the data unchanged.
    tempvar sortkey
    gen long `sortkey' = _n

    if "`interpolate'" == "linear" {
        sort `yearvar' `sortkey'
        tempvar ip
        quietly ipolate `theta_a' `yearvar' if `touse', gen(`ip')
        quietly replace `generate'theta = `ip' if `touse'
    }
    else if "`interpolate'" == "logit" {
        // Linear interpolation of log-odds(theta), inverted back to (0,1).
        // Requires all anchor thetas strictly in (0,1); if not, fall through
        // to linear with a warning.
        tempvar bad
        quietly gen byte `bad' = ///
            (`theta_a' <= 0 | `theta_a' >= 1) & !missing(`theta_a')
        quietly count if `bad'
        if r(N) > 0 {
            di as text "note: interpolate(logit) requires 0<theta<1 at anchors; " ///
                "some anchors fall outside (0,1); falling back to linear."
            sort `yearvar' `sortkey'
            tempvar ip
            quietly ipolate `theta_a' `yearvar' if `touse', gen(`ip')
            quietly replace `generate'theta = `ip' if `touse'
        }
        else {
            tempvar lgt lgt_ip
            quietly gen double `lgt' = logit(`theta_a')
            sort `yearvar' `sortkey'
            quietly ipolate `lgt' `yearvar' if `touse', gen(`lgt_ip')
            quietly replace `generate'theta = invlogit(`lgt_ip') if `touse'
        }
    }
    else if "`interpolate'" == "nearest" {
        sort `yearvar' `sortkey'
        tempvar prev nxt prev_yr nxt_yr
        quietly gen double `prev'    = `theta_a'
        quietly gen double `nxt'     = `theta_a'
        quietly gen double `prev_yr' = `yearvar' if !missing(`theta_a')
        quietly gen double `nxt_yr'  = `yearvar' if !missing(`theta_a')
        // Forward fill.
        quietly replace `prev'    = `prev'[_n-1]    if missing(`prev')    & `touse' & _n > 1
        quietly replace `prev_yr' = `prev_yr'[_n-1] if missing(`prev_yr') & `touse' & _n > 1
        // Backward fill via descending pass.
        gsort - `yearvar' - `sortkey'
        quietly replace `nxt'    = `nxt'[_n-1]    if missing(`nxt')    & `touse' & _n > 1
        quietly replace `nxt_yr' = `nxt_yr'[_n-1] if missing(`nxt_yr') & `touse' & _n > 1
        sort `yearvar' `sortkey'
        quietly replace `generate'theta = cond(missing(`prev'), `nxt', ///
            cond(missing(`nxt'), `prev', ///
                cond(`yearvar' - `prev_yr' <= `nxt_yr' - `yearvar', `prev', `nxt'))) ///
            if `touse'
    }

    // ---- Tail behavior (only affects rows outside the anchor year range).
    quietly summarize `yearvar' if `touse' & `generate'at_anchor == 1, meanonly
    local ya_min = r(min)
    local ya_max = r(max)

    if "`tails'" == "flat" {
        sort `yearvar' `sortkey'
        // Flat forward.
        quietly replace `generate'theta = `generate'theta[_n-1] ///
            if `touse' & missing(`generate'theta) & !missing(`generate'theta[_n-1])
        // Flat backward.
        gsort - `yearvar' - `sortkey'
        quietly replace `generate'theta = `generate'theta[_n-1] ///
            if `touse' & missing(`generate'theta) & !missing(`generate'theta[_n-1])
        sort `yearvar' `sortkey'
    }
    else if "`tails'" == "linear" & `nA' >= 2 {
        // Linear extrapolation from the two nearest anchor values on each end.
        tempvar y2 v_min v_ym1 v_max
        // Second-lowest anchor year.
        quietly summarize `yearvar' if `touse' & `generate'at_anchor == 1 & `yearvar' > `ya_min', meanonly
        local y2 = r(min)
        quietly summarize `generate'published if `touse' & `yearvar' == `ya_min', meanonly
        local v_min = r(mean)
        quietly summarize `generate'published if `touse' & `yearvar' == `y2', meanonly
        local v_y2 = r(mean)
        quietly summarize `generate'published if `touse' & `yearvar' == `ya_max', meanonly
        local v_max = r(mean)
        // Second-highest anchor year.
        quietly summarize `yearvar' if `touse' & `generate'at_anchor == 1 & `yearvar' < `ya_max', meanonly
        local ym1 = r(max)
        quietly summarize `generate'published if `touse' & `yearvar' == `ym1', meanonly
        local v_ym1 = r(mean)

        local theta_min = `v_min' / `v_min' * ( `v_min' /  `v_min' )  // placeholder; recomputed below
        // Reconstruct theta at those anchor years from the C_t at those years.
        tempvar nc_ymin nc_y2 nc_ym1 nc_ymax
        quietly summarize `ncvar' if `touse' & `yearvar' == `ya_min', meanonly
        local nc_ymin = r(mean)
        quietly summarize `ncvar' if `touse' & `yearvar' == `y2', meanonly
        local nc_y2 = r(mean)
        quietly summarize `ncvar' if `touse' & `yearvar' == `ym1', meanonly
        local nc_ym1 = r(mean)
        quietly summarize `ncvar' if `touse' & `yearvar' == `ya_max', meanonly
        local nc_ymax = r(mean)

        local theta_ymin = `v_min' / `nc_ymin'
        local theta_y2   = `v_y2'  / `nc_y2'
        local theta_ym1  = `v_ym1' / `nc_ym1'
        local theta_ymax = `v_max' / `nc_ymax'
        local slope_head = (`theta_y2' - `theta_ymin') / (`y2' - `ya_min')
        local slope_tail = (`theta_ymax' - `theta_ym1') / (`ya_max' - `ym1')
        quietly replace `generate'theta = `theta_ymin' + `slope_head' * (`yearvar' - `ya_min') ///
            if `touse' & missing(`generate'theta) & `yearvar' < `ya_min'
        quietly replace `generate'theta = `theta_ymax' + `slope_tail' * (`yearvar' - `ya_max') ///
            if `touse' & missing(`generate'theta) & `yearvar' > `ya_max'
        di as text "note: tails(linear) extrapolated theta beyond anchor range " ///
            "[" `ya_min' ", " `ya_max' "]. Interpret extrapolated years with caution."
    }
    // "missing" -> leave gaps.

    // ---- Restore original row order.
    sort `sortkey'
    drop `sortkey'

    // ---- Compute the estimated undocumented count and residual lawful.
    quietly gen double `generate'undoc  = `generate'theta * `ncvar' if `touse'
    quietly gen double `generate'lawful = `ncvar' - `generate'undoc if `touse'

    if "`pop'" != "" {
        quietly gen double `generate'pct_pop = `generate'undoc / `pop' if `touse'
        label variable `generate'pct_pop "Estimated undocumented share of total population"
    }

    label variable `generate'theta     "Interpolated theta_t (U/C), residual-method anchor interpolation"
    label variable `generate'undoc     "Estimated undocumented population (residual-method anchor interp.)"
    label variable `generate'lawful    "Residual legal noncitizens (C_t - U_hat_t)"
    label variable `generate'published "Published anchor value (source: `sourcename')"
    label variable `generate'at_anchor "1 if year is a residual-method anchor"

    // ---- Verification: identity must hold at every anchor row within 1 unit.
    tempvar dev
    quietly gen double `dev' = abs(`generate'undoc - `generate'published) ///
        if `touse' & `generate'at_anchor == 1
    quietly summarize `dev', meanonly
    if r(N) > 0 & r(max) > 1 {
        di as err "residualundoc interp: anchor identity failed " ///
            "(max |estimate - published| = " r(max) " at an anchor row)"
        exit 459
    }

    di as text _n "residualundoc interp: source=" as result "`sourcename'" ///
        as text ", anchors=" as result `nA' as text ", years=[" ///
        as result `ya_min' as text ", " as result `ya_max' as text "], " ///
        "interp=" as result "`interpolate'" as text ", tails=" as result "`tails'"

    return scalar N_anchors    = `nA'
    return local  anchor_years  `"`years_'"'
    return local  anchor_values `"`values_'"'
    return local  anchor_source `"`sourcename'"'
    return local  interp        `"`interpolate'"'
    return local  tails         `"`tails'"'
end
