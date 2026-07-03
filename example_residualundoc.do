********************************************************************************
* example_residualundoc.do
*
* Worked example for the residualundoc package. Illustrates all five
* subcommands (interp, apply, direct, transport, triangulate) plus the
* PUMS-integration pattern, with a small, self-contained synthetic dataset that
* mimics ACS/CMS/MPI/Pew inputs for the United States and Texas, 2010-2024. No
* external data required (the PUMS section uses simulated microdata).
*
* This example is didactic. The values are close enough to real 2010-2024
* estimates to be recognizable but should not be used as authoritative
* estimates. For a production application see the workflow in
*   Undocumented_Estimation/code/01_acs_residual_undocumented_estimates.do
*
* Reference:
*   Warren R, Warren JR, Zheng P (2023). "A New Residual Approach for
*   Estimating Undocumented Populations." International Migration Review.
*   doi:10.1177/01979183231195280
********************************************************************************

version 15.0
clear all
set more off

* -------------------------------------------------------------------------------
* 0. Make -residualundoc- discoverable
* -------------------------------------------------------------------------------
* Adjust this path to wherever this .ado family lives on your machine. On the
* Texas 2036 workstation, running from -stata_package/- picks up the ados in
* the current directory automatically via -adopath ++-.
adopath ++ "`c(pwd)'"

* -------------------------------------------------------------------------------
* 1. Build a synthetic ACS-like panel: geo x year with noncitizens, population,
*    and a noncitizen uninsured rate. Values are hand-tuned to roughly match
*    ACS 1-year detailed table values for 2010-2024.
* -------------------------------------------------------------------------------
input str14 geo int year double pop_total double noncitizen_total double noncitizen_unins_rate
"United States" 2010  309000000  22600000  0.44
"United States" 2011  311000000  22400000  0.45
"United States" 2012  313000000  22200000  0.44
"United States" 2013  315000000  22200000  0.44
"United States" 2014  317000000  22100000  0.36
"United States" 2015  319000000  22200000  0.35
"United States" 2016  321000000  22400000  0.31
"United States" 2017  323000000  22300000  0.31
"United States" 2018  326000000  22000000  0.30
"United States" 2019  328000000  21900000  0.29
"United States" 2021  332000000  21400000  0.31
"United States" 2022  333000000  22000000  0.29
"United States" 2023  335000000  23200000  0.29
"United States" 2024  337000000  24700000  0.29
"Texas"         2010   25200000   2960000  0.53
"Texas"         2011   25600000   2960000  0.54
"Texas"         2012   26000000   2950000  0.53
"Texas"         2013   26500000   2960000  0.51
"Texas"         2014   27000000   2960000  0.45
"Texas"         2015   27500000   2960000  0.44
"Texas"         2016   28000000   2990000  0.40
"Texas"         2017   28300000   2990000  0.41
"Texas"         2018   28700000   2980000  0.41
"Texas"         2019   29000000   2960000  0.40
"Texas"         2021   29500000   2860000  0.44
"Texas"         2022   30000000   2960000  0.42
"Texas"         2023   30500000   3200000  0.44
"Texas"         2024   31000000   3400000  0.44
end
label variable noncitizen_total     "ACS noncitizens (synthetic)"
label variable pop_total            "Total population (synthetic)"
label variable noncitizen_unins_rate "ACS noncitizen uninsured rate (synthetic)"

* -------------------------------------------------------------------------------
* 2. residualundoc interp: apply a Pew U.S. anchor series and an MPI Texas
*    anchor series to the same panel. Each residualundoc call operates on its
*    own if-subset (one geography at a time).
* -------------------------------------------------------------------------------

di as text _n "==================== U.S. Pew anchor interpolation ===================="
residualundoc interp year noncitizen_total if geo == "United States", ///
    anchors(2010=11400000 2015=11000000 2017=10500000 2019=10200000 ///
            2021=10500000 2022=11800000 2023=14000000)                ///
    sourcename(Pew) pop(pop_total) generate(u_pew_)

di as text _n "==================== Texas MPI anchor interpolation ===================="
residualundoc interp year noncitizen_total if geo == "Texas",         ///
    anchors(2019=1739000 2023=1966000)                                 ///
    sourcename(MPI) pop(pop_total) generate(u_mpi_)

di as text _n "==================== Texas CMS anchor series ===================="
* Illustrates a second anchor set on the same rows; a different -generate()-
* prefix keeps its output distinct from the MPI series.
residualundoc interp year noncitizen_total if geo == "Texas",         ///
    anchors(2016=1597000 2018=1730000 2023=2052500 2024=2317000)      ///
    sourcename(CMS) pop(pop_total) generate(u_cms_)

* Quick verification: at every MPI-anchor Texas row, u_mpi_undoc == published.
assert abs(u_mpi_undoc - u_mpi_published) < 1 if u_mpi_at_anchor == 1

list geo year noncitizen_total u_pew_undoc u_mpi_undoc u_cms_undoc ///
    if inlist(year, 2015, 2019, 2023, 2024), sep(0) noobs abbrev(20)

* -------------------------------------------------------------------------------
* 2b. residualundoc apply: the cross-sectional (all-states) method. Apply one
*     national theta to every unit's noncitizen count in a single year, and
*     benchmark against a directly published state residual estimate. Calibrating
*     theta to the sum of the direct estimates makes the totals match by
*     construction, so the per-unit gap is purely the cost of a uniform theta.
* -------------------------------------------------------------------------------

di as text _n "==================== Cross-section: apply one theta across states (2024) ===================="
preserve
    clear
    input str2 st double noncit double cms_direct double noncit_moe
    "CA" 5003494 2631000  61000
    "TX" 3350974 2317000  49000
    "FL" 2433707 1427000  40000
    "NY" 1877763  920000  35000
    "GA"  698506  502000  20000
    "LA"  145600  124000   9000
    end
    * moe() gives the 90% ACS sampling interval; srcrse() optionally widens it
    * into a robustness band (source spread), which is not a formal CI.
    residualundoc apply noncit, direct(cms_direct) tolerance(10) ///
        moe(noncit_moe) srcrse(0.024) generate(rf_)
    list st noncit cms_direct rf_undoc rf_lo rf_hi rf_pct, sep(0) noobs abbrev(12)
    di as text "returned: theta=" as result %6.4f r(theta) ///
        as text ", dissimilarity=" as result %5.3f r(dissimilarity) ///
        as text ", within 10% = " as result r(within_tol) as text " of " as result r(n_units)
restore

* -------------------------------------------------------------------------------
* 3. residualundoc transport: transport the ACS noncitizen uninsured rate to
*    MPI's 66.4% Texas 2023 undocumented uninsured benchmark, on the odds scale.
* -------------------------------------------------------------------------------

di as text _n "==================== Texas insurance rate transport ===================="
residualundoc transport noncitizen_unins_rate if geo == "Texas",     ///
    year(year) anchor(2023 0.664) scale(odds) generate(u_ins_)

* Ratio-scale comparison (retained as an anti-pattern for the report).
residualundoc transport noncitizen_unins_rate if geo == "Texas",     ///
    year(year) anchor(2023 0.664) scale(ratio) generate(u_ins_ratio_) replace

list year noncitizen_unins_rate u_ins_transported_rate u_ins_ratio_transported_rate ///
    if geo == "Texas" & inlist(year, 2010, 2013, 2019, 2023, 2024), sep(0) noobs

* Uninsured count = U_hat * transported rate.
quietly gen double u_uninsured = u_mpi_undoc * u_ins_transported_rate if geo == "Texas"
quietly gen double u_insured   = u_mpi_undoc - u_uninsured             if geo == "Texas"
label variable u_uninsured "Estimated uninsured undocumented, TX (main)"
label variable u_insured   "Estimated insured undocumented, TX (main)"

* -------------------------------------------------------------------------------
* 4. residualundoc triangulate: compare Pew, CMS, and MPI 2023 U.S. estimates
*    against this workflow's own value at the same year.
* -------------------------------------------------------------------------------

di as text _n "==================== U.S. 2023 triangulation ===================="
quietly summarize u_pew_undoc if geo == "United States" & year == 2023, meanonly
local workflow_us_2023 = r(mean)
residualundoc triangulate, year(2023) workflow(`workflow_us_2023')  ///
    sources(Pew=14000000 CMS=12244500 MPI=13738000)

di as text _n "==================== Texas 2023 triangulation ===================="
quietly summarize u_mpi_undoc if geo == "Texas" & year == 2023, meanonly
local workflow_tx_2023 = r(mean)
residualundoc triangulate, year(2023) workflow(`workflow_tx_2023')  ///
    sources(Pew=2050000 CMS=2052500 MPI=1966000)

* -------------------------------------------------------------------------------
* 5. residualundoc direct: Warren-style year-by-year residual construction.
*    Uses stylized DHS-like arrivals/naturalizations/deaths and derives
*    emigration so U_hat matches published Pew U.S. anchors in 2010 and 2023.
*
*    In production, the arrivals series comes from the DHS Yearbook (LPR
*    admissions + refugees + asylees + net change in nonimmigrants), and
*    deaths come from applying life-table survival rates to the previous
*    year's L_t. Here they are hand-set for pedagogy.
* -------------------------------------------------------------------------------

* Attach synthetic DHS-like series to the U.S. rows.
tempvar us_row
quietly gen byte `us_row' = (geo == "United States")
quietly gen double dhs_arrivals = .
quietly gen double dhs_natz     = .
quietly gen double dhs_deaths   = .
* Rough magnitudes: ~1M new LPRs, ~700k naturalizations, ~200k deaths per year.
quietly replace dhs_arrivals = 1050000 if `us_row'
quietly replace dhs_natz     =  720000 if `us_row'
quietly replace dhs_deaths   =  190000 if `us_row'

di as text _n "==================== U.S. direct Warren-style residual ===================="
residualundoc direct year noncitizen_total if geo == "United States",         ///
    arrivals(dhs_arrivals) natz(dhs_natz) deaths(dhs_deaths)                  ///
    l0(11175000)                                                              ///
    targetu(2010=11400000 2023=14000000)                                      ///
    generate(u_dir_)

list year noncitizen_total u_dir_L u_dir_undoc u_dir_emigration_used ///
    if geo == "United States" & inlist(year, 2010, 2015, 2019, 2023, 2024), sep(0) noobs

* Sanity check: U_hat should match the Pew anchors at target years by construction.
quietly summarize u_dir_undoc if geo == "United States" & year == 2010, meanonly
assert abs(r(mean) - 11400000) < 1
quietly summarize u_dir_undoc if geo == "United States" & year == 2023, meanonly
assert abs(r(mean) - 14000000) < 1

* -------------------------------------------------------------------------------
* 5b. Integrating ACS PUMS microdata (disaggregation with replicate-weight SEs)
*
*     The residual estimator works on aggregated counts, so PUMS enters as a
*     data-prep step: tabulate noncitizen counts by subgroup from the person
*     microdata (using the 80 replicate weights for standard errors), then feed
*     the cell counts to -apply- and -transport-. Below we simulate a tiny PUMS-
*     like file; with a real file, read psam_p*.csv, set noncit = (CIT==5) and
*     unins = (HICOV==2), and use PWGTP together with PWGTP1-PWGTP80.
* -------------------------------------------------------------------------------

di as text _n "==================== PUMS integration (simulated microdata) ===================="
preserve
    clear
    set seed 20260703
    quietly set obs 6000
    gen byte agegrp = 1 + int(3 * runiform())            // 1,2,3 illustrative age bins
    gen byte noncit = runiform() < 0.12
    gen byte unins  = runiform() < cond(noncit, 0.45, 0.09)
    gen double pwgtp = 15 + 35 * runiform()
    forvalues r = 1/80 {
        gen double pwgtp`r' = pwgtp * (0.9 + 0.2 * runiform())   // stand-in replicate weights
    }
    * Successive-difference replication is exactly the ACS PUMS variance method.
    svyset [pw=pwgtp], sdrweight(pwgtp1-pwgtp80) vce(sdr)
    di as text "Weighted noncitizen count by age group, with replicate-weight SE:"
    svy: total noncit, over(agegrp)

    * Collapse to cell counts, then feed them to the residual estimator.
    gen double nc_w   = pwgtp * noncit
    gen double ncun_w = pwgtp * noncit * unins
    collapse (sum) nc_w ncun_w, by(agegrp)
    gen double noncit_count  = nc_w
    gen double nc_unins_rate = ncun_w / nc_w
    gen int    year = 2024

    residualundoc apply noncit_count, theta(0.62) generate(cell_)
    residualundoc transport nc_unins_rate, year(year) anchor(2024 0.66) scale(odds) generate(cell_ins_)
    gen double cell_uninsured = cell_undoc * cell_ins_transported_rate
    label variable cell_undoc     "Undocumented estimate per cell (theta x noncit)"
    label variable cell_uninsured "Uninsured undocumented per cell"
    list agegrp noncit_count cell_undoc nc_unins_rate cell_ins_transported_rate cell_uninsured, ///
        sep(0) noobs abbrev(16)
    di as text "note: the undocumented-count SE is theta times the noncitizen-count SE from" ///
        _n "      -svy: total- above; carry that through for cell-level uncertainty."
restore

* -------------------------------------------------------------------------------
* 6. Wrap up
* -------------------------------------------------------------------------------
di as text _n "Example complete. Key output variables:"
di as text "  u_pew_*   -- U.S. Pew anchor-interpolation series"
di as text "  u_mpi_*   -- Texas MPI anchor-interpolation series"
di as text "  u_cms_*   -- Texas CMS anchor-interpolation series"
di as text "  u_ins_*   -- Texas transported uninsured rate (odds scale)"
di as text "  u_dir_*   -- U.S. direct Warren-style residual reconstruction"
di as text "  (apply and PUMS sections run on their own preserved subsets)"

* Optionally save the enriched panel next to this .do file for further use.
capture save "example_residualundoc.dta", replace
