*! version 1.0.0  Texas 2036 / Eric Booth  2026-07-02
*! residualundoc_transport: rate transport between two populations, calibrated
*! to a residual-method benchmark at one anchor year.
*! -----------------------------------------------------------------------------
*! Given a survey-measured rate r^S_t (e.g., ACS noncitizen uninsured rate) and
*! a residual-method benchmark rate r^U_a in a single anchor year a, compute
*! the transported rate r^hatU_t that matches r^U_a in year a and moves with
*! r^S_t in other years. Three transport scales are supported:
*!    odds  : odds(r^hatU) = kappa * odds(r^S), kappa = odds(r^U_a) / odds(r^S_a)
*!    logit : identical algebra, expressed as logit(r^hatU) = logit(r^S) + delta
*!    ratio : r^hatU = min(1, kappa * r^S), kappa = r^U_a / r^S_a  (may saturate)
*! Odds/logit are recommended because they keep r^hatU in (0, 1). See the report
*! for why the earlier ratio-scale calibration produced 85-89% pre-ACA rates.
*!
*! Syntax:
*!   residualundoc transport ratevar [if] [in],
*!       ANCHor(year value) [ YEar(varname) SCale(odds|logit|ratio)
*!                            GENerate(prefix) REPlace ]
*! -----------------------------------------------------------------------------

program define residualundoc_transport, rclass byable(recall)
    version 15.0

    syntax varlist(min=1 max=1 numeric) [if] [in] , ANCHor(string)  ///
        [ YEar(varname numeric) SCale(name) GENerate(string) REPlace ]

    local ratevar `varlist'
    if "`scale'"    == "" local scale "odds"
    if "`generate'" == "" local generate "u_"

    if !inlist("`scale'", "odds", "logit", "ratio") {
        di as err "scale() must be odds, logit, or ratio"
        exit 198
    }
    if "`year'" == "" {
        capture confirm numeric variable year
        if _rc {
            di as err "no year() specified and no numeric variable 'year' in dataset"
            exit 111
        }
        local year "year"
    }

    // Parse "year value".
    local rest = strtrim(`"`anchor'"')
    gettoken ay rest : rest, parse(" =")
    local rest = strtrim(`"`rest'"')
    if substr(`"`rest'"', 1, 1) == "=" local rest = substr(`"`rest'"', 2, .)
    gettoken av rest : rest, parse(" ")
    local ay = real("`ay'")
    local av = real("`av'")
    if missing(`ay') | missing(`av') {
        di as err "anchor() must be 'year value' (e.g., anchor(2023 0.664))"
        exit 198
    }
    if `av' <= 0 | `av' >= 1 {
        if "`scale'" != "ratio" {
            di as err "anchor value `av' must be in (0,1) for scale(`scale')"
            exit 198
        }
    }

    foreach suf in transported_rate transported_kappa {
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

    quietly summarize `ratevar' if `touse' & `year' == `ay', meanonly
    if r(N) == 0 {
        di as err "no observations at anchor year `ay'"
        exit 2000
    }
    local r_a = r(mean)
    if `r_a' <= 0 | `r_a' >= 1 {
        if "`scale'" != "ratio" {
            di as err "survey rate at anchor year (`r_a') outside (0,1); cannot use scale(`scale')"
            exit 198
        }
    }

    tempname kappa
    if "`scale'" == "odds" {
        scalar `kappa' = (`av' / (1 - `av')) / (`r_a' / (1 - `r_a'))
    }
    else if "`scale'" == "logit" {
        // Additive on the logit scale is equivalent to multiplicative on the
        // odds scale; here we store delta = logit(av) - logit(r_a) in kappa.
        scalar `kappa' = logit(`av') - logit(`r_a')
    }
    else {
        scalar `kappa' = `av' / `r_a'
    }

    quietly gen double `generate'transported_kappa = `kappa'

    if "`scale'" == "odds" {
        tempvar odds_s
        quietly gen double `odds_s' = `ratevar' / (1 - `ratevar')
        quietly gen double `generate'transported_rate = ///
            (`kappa' * `odds_s') / (1 + `kappa' * `odds_s') if `touse'
    }
    else if "`scale'" == "logit" {
        quietly gen double `generate'transported_rate = ///
            invlogit(logit(`ratevar') + `kappa') if `touse'
    }
    else {
        quietly gen double `generate'transported_rate = ///
            min(1, `ratevar' * `kappa') if `touse'
    }

    label variable `generate'transported_rate  "Transported rate to residual-method benchmark at year `ay' (scale=`scale')"
    label variable `generate'transported_kappa "Calibration constant (scale=`scale')"

    di as text "residualundoc transport: scale=" as result "`scale'" ///
        as text ", kappa=" as result %10.6f `kappa' as text ///
        ", anchor=(" as result `ay' as text ", " as result %6.4f `av' as text ")"

    return scalar kappa        = `kappa'
    return scalar anchor_year  = `ay'
    return scalar anchor_value = `av'
    return local  scale         `"`scale'"'
end
