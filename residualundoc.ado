*! version 1.1.0  Texas 2036 / Eric Booth  2026-07-03
*! residualundoc: residual-method estimator of the undocumented population.
*! -----------------------------------------------------------------------------
*! Implements a family of residual-method estimators of the undocumented
*! (unauthorized) immigrant population, following Warren, Warren & Zheng (2023),
*! "A New Residual Approach for Estimating Undocumented Populations,"
*! International Migration Review, DOI 10.1177/01979183231195280.
*!
*! Residual identity (Warren et al. 2023):
*!    U_t = C_t - L_t
*! where C_t is survey-measured noncitizens (ACS, adjusted for undercount) and
*! L_t is the legal noncitizen population reconstructed year-by-year from
*! administrative data (DHS lawful admissions, naturalizations, mortality via
*! life tables, and derived-from-ACS emigration). Because L_t moves slowly,
*! theta_t = U_t/C_t = 1 - L_t/C_t is a slow-moving demographic quantity that
*! can be linearly interpolated between years with credible published U_t
*! anchors (e.g., Pew, MPI, CMS residual-method releases).
*!
*! Subcommands:
*!   residualundoc interp        Anchor-interpolation over time (theta interpolation)
*!   residualundoc apply         Cross-sectional: one theta across units, with an
*!                               optional benchmark vs a direct estimate
*!   residualundoc direct        Direct year-by-year residual (Warren et al.)
*!   residualundoc transport     Rate transport on odds/logit/ratio scale
*!   residualundoc triangulate   Multi-source comparison at a given year
*!
*! The interp/apply/transport/triangulate subcommands operate on aggregated
*! counts and rates. To disaggregate below the published tables, tabulate the
*! survey noncitizen counts by subgroup from ACS PUMS microdata (with replicate
*! weights for standard errors) and feed those cell counts to -apply- and
*! -transport-; see -help residualundoc- (PUMS integration) and the worked
*! example do-file.
*!
*! See -help residualundoc- for full syntax and options.
*! -----------------------------------------------------------------------------

program define residualundoc, rclass
    version 15.0

    gettoken subcmd 0 : 0, parse(" ,")
    local subcmd = strtrim(`"`subcmd'"')
    local known "interp apply direct transport triangulate"
    if !`: list subcmd in known' {
        // No recognized subcommand -> default to -interp-.
        local 0 `"`subcmd' `0'"'
        local subcmd "interp"
    }

    if "`subcmd'" == "interp" {
        residualundoc_interp `0'
    }
    else if "`subcmd'" == "apply" {
        residualundoc_apply `0'
    }
    else if "`subcmd'" == "direct" {
        residualundoc_direct `0'
    }
    else if "`subcmd'" == "transport" {
        residualundoc_transport `0'
    }
    else if "`subcmd'" == "triangulate" {
        residualundoc_triangulate `0'
    }
    return add
end
