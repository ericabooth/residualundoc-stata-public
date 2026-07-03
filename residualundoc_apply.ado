*! version 1.1.0  Texas 2036 / Eric Booth  2026-07-03
*! residualundoc_apply: cross-sectional application of a single (national) theta
*! across many units (e.g., states) in one year, with an optional benchmark
*! comparison against a directly published residual estimate.
*! -----------------------------------------------------------------------------
*! This packages the all-states method in Booth (2026): apply one undocumented
*! share of noncitizens, theta, to every unit's survey noncitizen count,
*!   U_hat_g = theta * C_g,
*! and, if a state-specific ("direct") published residual estimate is supplied,
*! report where the single-theta shortcut agrees and where it misses. theta can
*! be given directly or calibrated so the shortcut reproduces a published total
*! across units (theta = sum(published)/sum(C) or sum(direct)/sum(C)); with that
*! calibration the totals match by construction and the per-unit gap is purely
*! the cost of assuming theta is uniform across units.
*!
*! Syntax:
*!   residualundoc apply noncitizensvar [if] [in],
*!       ( THETA(#) | PUBlished(varname) | DIRect(varname) )
*!       [ GENerate(prefix) TOLerance(#) MOE(varname) SRCrse(# | varname)
*!         CIlevel(#) REPlace ]
*!
*! Diagnostics returned when direct() is given: the share of units within
*! +/- TOLerance percent of the direct estimate, and the index of dissimilarity
*!   D = 0.5 * sum|U_hat_g - direct_g| / sum(direct_g),
*! the share of the total that the single-theta shortcut assigns to the wrong
*! unit relative to the direct estimates.
*!
*! Optional intervals: give MOE(varname) (the ACS 90% margin of error on the
*! noncitizen count) to add an ACS sampling confidence interval on U_hat.
*! SRCrse() optionally WIDENS that interval into a robustness band using a
*! source-spread term (a constant or per-unit variable, e.g. the cross-source CV
*! of the anchor). A few non-independent published estimates are not a sampling
*! distribution, so the widened band is a robustness range, not a formal CI;
*! reporting the source min-max range separately is usually preferable. Creates
*! prefix-moe/lo/hi at CIlevel() (default 90). Undercount uncertainty excluded.
*! -----------------------------------------------------------------------------

program define residualundoc_apply, rclass byable(recall)
    version 15.0

    syntax varlist(min=1 max=1 numeric) [if] [in] ,          ///
        [ THETA(real -1) PUBlished(varname numeric)          ///
          DIRect(varname numeric) GENerate(string)           ///
          TOLerance(real 10) MOE(varname numeric)            ///
          SRCrse(string) CIlevel(real 90) REPlace ]

    local ncvar `varlist'
    if "`generate'" == "" local generate "u_"

    // ---- Resolve the source of theta.
    local nsrc = ("`published'" != "") + ("`direct'" != "") + (`theta' >= 0)
    if `nsrc' == 0 {
        di as err "specify one of theta(#), published(varname), or direct(varname)"
        exit 198
    }
    if `nsrc' > 1 {
        di as err "specify only one of theta(), published(), or direct()"
        exit 198
    }

    // ---- Output-variable guards.
    local outs undoc
    if "`direct'" != "" local outs "`outs' diff pct"
    if "`moe'" != ""    local outs "`outs' moe lo hi"
    foreach suf of local outs {
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

    quietly count if `touse'
    local nunits = r(N)
    if `nunits' == 0 {
        di as err "no observations meet if/in"
        exit 2000
    }

    // ---- Determine theta.
    if "`published'" != "" | "`direct'" != "" {
        local calvar = cond("`published'" != "", "`published'", "`direct'")
        quietly summarize `calvar' if `touse', meanonly
        local sump = r(sum)
        quietly summarize `ncvar' if `touse', meanonly
        local sumc = r(sum)
        if `sumc' == 0 {
            di as err "sum of `ncvar' is zero; cannot calibrate theta"
            exit 198
        }
        local theta = `sump' / `sumc'
        local thetasrc = "calibrated to sum(`calvar')"
    }
    else {
        local thetasrc = "supplied"
    }
    if `theta' <= 0 | `theta' >= 1 {
        di as text "note: theta = " %6.4f `theta' " is outside (0,1); proceeding anyway."
    }

    // ---- Reduced-form estimate.
    quietly gen double `generate'undoc = `theta' * `ncvar' if `touse'
    label variable `generate'undoc "Reduced-form undocumented (theta x `ncvar')"

    // ---- Benchmark comparison, if a direct estimate is supplied.
    if "`direct'" != "" {
        quietly gen double `generate'diff = `generate'undoc - `direct' if `touse'
        quietly gen double `generate'pct  = ///
            100 * (`generate'undoc / `direct' - 1) if `touse' & `direct' != 0
        label variable `generate'diff "Reduced-form minus direct estimate"
        label variable `generate'pct  "Reduced-form vs direct, percent"

        tempvar absd
        quietly gen double `absd' = abs(`generate'diff) if `touse'
        quietly summarize `absd' if `touse', meanonly
        local sumabs = r(sum)
        quietly summarize `direct' if `touse', meanonly
        local sumdir = r(sum)
        local D = 0.5 * `sumabs' / `sumdir'
        quietly count if `touse' & abs(`generate'pct) <= `tolerance' & !missing(`generate'pct)
        local nwithin = r(N)

        di as text _n "residualundoc apply: theta=" as result %6.4f `theta' ///
            as text " (`thetasrc'), units=" as result `nunits'
        di as text "  within +/-" as result `tolerance' as text "% of direct: " ///
            as result `nwithin' as text " of " as result `nunits'
        di as text "  index of dissimilarity D=" as result %5.3f `D' ///
            as text " (" as result %4.1f 100 * `D' as text ///
            "% of the total assigned to the wrong unit vs direct)"

        return scalar dissimilarity  = `D'
        return scalar within_tol     = `nwithin'
        return scalar within_share   = `nwithin' / `nunits'
        return scalar tolerance      = `tolerance'
    }
    else {
        di as text _n "residualundoc apply: theta=" as result %6.4f `theta' ///
            as text " (`thetasrc'), units=" as result `nunits'
    }

    // ---- Optional intervals: ACS sampling CI (moe()); srcrse() widens to a
    //      robustness band (source spread in quadrature), not a formal CI.
    if "`moe'" != "" {
        local z = invnormal(1 - (1 - `cilevel'/100)/2)
        // Source-spread relative SE: a constant number, a variable, or none.
        tempvar srcv
        if "`srcrse'" == "" {
            quietly gen double `srcv' = 0
        }
        else {
            capture confirm number `srcrse'
            if _rc == 0 {
                quietly gen double `srcv' = `srcrse'
            }
            else {
                capture confirm numeric variable `srcrse'
                if _rc {
                    di as err "srcrse() must be a number or a numeric variable"
                    exit 198
                }
                quietly gen double `srcv' = `srcrse'
            }
        }
        // ACS margins are 90% margins, so SE = moe/1.645 regardless of cilevel().
        tempvar samprse
        quietly gen double `samprse' = (`moe' / 1.645) / `ncvar' if `touse'
        quietly gen double `generate'moe = ///
            `z' * sqrt(`samprse'^2 + `srcv'^2) * `generate'undoc if `touse'
        quietly gen double `generate'lo = `generate'undoc - `generate'moe if `touse'
        quietly gen double `generate'hi = `generate'undoc + `generate'moe if `touse'
        if "`srcrse'" == "" {
            label variable `generate'moe "`cilevel'% ACS sampling margin"
        }
        else {
            label variable `generate'moe "`cilevel'% robustness band (ACS sampling + source spread)"
        }
        label variable `generate'lo  "`cilevel'% lower bound"
        label variable `generate'hi  "`cilevel'% upper bound"
        return scalar cilevel = `cilevel'
    }

    return scalar theta   = `theta'
    return scalar n_units = `nunits'
    return local  theta_source `"`thetasrc'"'
end
