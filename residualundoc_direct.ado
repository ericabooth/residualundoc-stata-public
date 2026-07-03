*! version 1.0.0  Texas 2036 / Eric Booth  2026-07-02
*! residualundoc_direct: Warren-style direct year-by-year residual construction.
*! -----------------------------------------------------------------------------
*! Implements the residual accounting of Warren, Warren & Zheng (2023) directly.
*! The legal noncitizen stock is rolled forward each year as
*!    L_t = L_{t-1} + arrivals_t - naturalizations_t - deaths_t - emigration_t
*! and the estimated undocumented population is the residual
*!    U_hat_t = C_t - L_t
*! where C_t is ACS noncitizens (optionally scaled up by an undercount factor).
*!
*! Emigration handling:
*!   - If -emigration()- is supplied it is used verbatim.
*!   - If a rate is supplied (-asrate-), emigration_t = rate_t * L_{t-1}.
*!   - Otherwise, if -targetu(year=value ...)- provides target U_t values at
*!     one or more years, emigration is derived so that U_hat_t hits those
*!     targets at those years (this is Warren's "derive emigration from ACS"
*!     innovation, applied to any year with a residual-method anchor).
*!
*! Syntax:
*!   residualundoc direct yearvar noncitizensvar [if] [in],
*!       ARrivals(varname) NAtz(varname) DEaths(varname)
*!       L0(real) [ EMigration(varname) ASrate
*!                  UNDERcount(varname) TARGetu(spec)
*!                  GENerate(prefix) REPlace ]
*! -----------------------------------------------------------------------------

program define residualundoc_direct, rclass byable(recall)
    version 15.0

    syntax varlist(min=2 max=2 numeric) [if] [in] , ///
        ARrivals(varname numeric) NAtz(varname numeric) DEaths(varname numeric) ///
        L0(real)                                                              ///
        [ EMigration(varname numeric) ASrate                                  ///
          UNDERcount(varname numeric) TARGetu(string)                         ///
          GENerate(string) REPlace ]

    tokenize `varlist'
    local yearvar `1'
    local ncvar   `2'
    if "`generate'" == "" local generate "u_"

    foreach suf in L undoc emigration_used arrivals_adj nc_adj {
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
    tempvar sortkey
    gen long `sortkey' = _n
    sort `yearvar' `sortkey'

    // Undercount adjustment applies to both arrivals and the C count itself.
    quietly gen double `generate'arrivals_adj = `arrivals'
    quietly gen double `generate'nc_adj       = `ncvar'
    if "`undercount'" != "" {
        quietly replace `generate'arrivals_adj = `arrivals' * (1 + `undercount')
        quietly replace `generate'nc_adj       = `ncvar'    * (1 + `undercount')
    }

    quietly gen double `generate'L              = .
    quietly gen double `generate'undoc          = .
    quietly gen double `generate'emigration_used = .

    // Parse -targetu()- into parallel locals.
    local tyears  ""
    local tvalues ""
    local nT = 0
    if "`targetu'" != "" {
        local rest `"`targetu'"'
        while `"`rest'"' != "" {
            gettoken tok rest : rest, parse(" ")
            local tok = strtrim(`"`tok'"')
            if `"`tok'"' == "" continue
            local eqpos = strpos(`"`tok'"', "=")
            if `eqpos' == 0 {
                di as err "targetu() token '`tok'' must be year=value"
                exit 198
            }
            local yr = substr(`"`tok'"', 1, `eqpos' - 1)
            local vl = substr(`"`tok'"', `eqpos' + 1, .)
            local tyears  "`tyears' `yr'"
            local tvalues "`tvalues' `vl'"
            local ++nT
        }
    }

    // ---- Rolling recursion over ascending years in the touse subset.
    quietly levelsof `yearvar' if `touse', local(yrs)
    tokenize `yrs'
    local y0 : word 1 of `yrs'
    // If the first year is itself a residual-method target, use the target
    // directly (Warren identity: L_{y0} = C_{y0}^adj - U_target_{y0}). This
    // overrides -l0()- when it would otherwise conflict with a target.
    local l0_used = `l0'
    if `nT' > 0 {
        forvalues i = 1/`nT' {
            local tyr : word `i' of `tyears'
            local tvl : word `i' of `tvalues'
            if `tyr' == `y0' {
                quietly summarize `generate'nc_adj if `touse' & `yearvar' == `y0', meanonly
                local l0_used = r(mean) - `tvl'
                di as text "note: l0 overridden by targetu at y0=`y0': L_" ///
                    "`y0' = C^adj - U_target = " %14.0fc `l0_used'
                continue, break
            }
        }
    }
    quietly replace `generate'L = `l0_used' if `touse' & `yearvar' == `y0'
    quietly replace `generate'undoc = `generate'nc_adj - `generate'L ///
        if `touse' & `yearvar' == `y0'

    local prevY `y0'
    foreach y of local yrs {
        if "`y'" == "`y0'" continue
        // Gather this-year components.
        quietly summarize `generate'arrivals_adj if `touse' & `yearvar' == `y', meanonly
        local A = r(mean)
        quietly summarize `natz'   if `touse' & `yearvar' == `y', meanonly
        local Nz = r(mean)
        quietly summarize `deaths' if `touse' & `yearvar' == `y', meanonly
        local D = r(mean)
        quietly summarize `generate'L if `touse' & `yearvar' == `prevY', meanonly
        local Lprev = r(mean)

        // Emigration: user-supplied, else target-derived if a target exists at y.
        local Em .
        if "`emigration'" != "" {
            if "`asrate'" == "asrate" {
                quietly summarize `emigration' if `touse' & `yearvar' == `y', meanonly
                local rateE = r(mean)
                local Em = `rateE' * `Lprev'
            }
            else {
                quietly summarize `emigration' if `touse' & `yearvar' == `y', meanonly
                local Em = r(mean)
            }
        }
        else if `nT' > 0 {
            // Look for a target U_t at year y.
            local matched 0
            forvalues i = 1/`nT' {
                local tyr : word `i' of `tyears'
                local tvl : word `i' of `tvalues'
                if `tyr' == `y' {
                    // U_target = C_adj - L; so L_target = C_adj - U_target.
                    quietly summarize `generate'nc_adj if `touse' & `yearvar' == `y', meanonly
                    local C = r(mean)
                    local Ltarget = `C' - `tvl'
                    // Em such that Lprev + A - Nz - D - Em = Ltarget
                    local Em = `Lprev' + `A' - `Nz' - `D' - `Ltarget'
                    local matched 1
                    continue, break
                }
            }
            if `matched' == 0 {
                local Em = 0
            }
        }
        else {
            local Em = 0
        }

        local Lnew = `Lprev' + `A' - `Nz' - `D' - `Em'
        quietly replace `generate'L = `Lnew' if `touse' & `yearvar' == `y'
        quietly replace `generate'emigration_used = `Em' if `touse' & `yearvar' == `y'
        quietly replace `generate'undoc = `generate'nc_adj - `generate'L ///
            if `touse' & `yearvar' == `y'
        local prevY `y'
    }

    label variable `generate'L               "Reconstructed legal noncitizens L_t (Warren residual)"
    label variable `generate'undoc           "Estimated undocumented U_t = C_t^{adj} - L_t"
    label variable `generate'emigration_used "Emigration used at each step (supplied or target-derived)"
    label variable `generate'arrivals_adj    "Arrivals adjusted for undercount"
    label variable `generate'nc_adj          "ACS noncitizens adjusted for undercount"

    sort `sortkey'
    drop `sortkey'

    quietly count if `touse'
    di as text "residualundoc direct: L reconstructed for " as result r(N) ///
        as text " rows; L_" as result "`y0'" as text " = " as result %14.0fc `l0_used' ///
        as text (cond("`emigration'" == "" & `nT' > 0, ", emigration derived from `nT' target(s)", ""))

    return scalar L0    = `l0_used'
    return scalar N     = r(N)
    return local  y0     `"`y0'"'
    return scalar Nanchors = `nT'
end
