# residualundoc

A small Stata package for estimating the undocumented (unauthorized) immigrant
population with the residual method of Warren, Warren, and Zheng (2023):

```
U = C - L
```

where `C` is survey-measured noncitizens (typically the ACS) and `L` is the legal
noncitizen population. Because `L` moves slowly, the ratio `theta = U/C` (the
undocumented share of noncitizens) is a slow-moving quantity that can be pinned to
a few published residual-method estimates (Pew, MPI, CMS) and interpolated in
between. The package turns that idea, and several relatives of it, into one command.

## Install

From this repository (replace `USER` with the GitHub account hosting it):

```stata
net install residualundoc, ///
    from("https://raw.githubusercontent.com/USER/residualundoc-stata-public/main/") replace
help residualundoc
```

Or clone/download and add the folder to your ado-path:

```stata
adopath ++ "/path/to/residualundoc-stata-public"
help residualundoc
```

Requires Stata 15 or later. The mapping in the accompanying analysis also uses
`maptile`/`spmap`, but those are not needed for this package.

## Subcommands

| Subcommand | What it does |
|---|---|
| `interp` | Anchor-interpolation of `theta` **over time**: import published values at anchor years, interpolate between, multiply back by the ACS count. |
| `apply` | The **cross-sectional** method: apply one `theta` across many units (e.g. states) in a single year; optionally benchmark against a directly published estimate (share within tolerance + index of dissimilarity) and attach an ACS sampling confidence interval (optionally widened to a robustness band via `srcrse()`). |
| `direct` | Warren-style **year-by-year** reconstruction of `L` from DHS arrivals, naturalizations, life-table deaths, and supplied or anchor-derived emigration. |
| `transport` | Transport a survey rate (e.g. the ACS noncitizen uninsured rate) to a residual-method benchmark rate at one anchor year, on the **odds**, logit, or ratio scale. |
| `triangulate` | Side-by-side comparison of residual-method estimates from several sources at one year, with an optional workflow value. |

## Quick start

```stata
* Time series: interpolate a Pew U.S. anchor series across an ACS panel
residualundoc interp year noncitizen_total if geo=="United States", ///
    anchors(2010=11400000 2015=11000000 2019=10200000 2023=14000000) ///
    sourcename(Pew) generate(u_)

* Cross-section: one national theta across states, benchmarked to a direct
* estimate, with a 90% ACS sampling interval (moe); srcrse() would widen it
* into a robustness band, so report the source min-max range separately instead
residualundoc apply noncitizen_total, direct(cms_direct) ///
    moe(noncit_moe) tolerance(10) generate(rf_)
di r(theta), r(dissimilarity), r(within_tol)

* Insurance: transport the ACS noncitizen uninsured rate to a benchmark
residualundoc transport noncitizen_unins_rate, year(year) ///
    anchor(2023 0.664) scale(odds) generate(u_ins_)
```

Run `example_residualundoc.do` for a self-contained tour of all five subcommands
plus the ACS PUMS integration pattern. It uses simulated data and needs no
Census API key or external download.

## Going below the published tables (ACS PUMS)

The estimator works on aggregated counts, so person-level ACS PUMS enters as a
data-prep step: tabulate noncitizen counts by subgroup from the PUMS person file
(using `svyset ... , sdrweight(...) vce(sdr)` with the 80 replicate weights for
standard errors), then feed the cell counts to `apply` and `transport`. See
`help residualundoc` ("Integrating ACS PUMS microdata") and Section 5b of the
example do-file. These are transported estimates, not person-level legal-status
imputations.

## Accompanying draft analysis

This package was built alongside a draft Texas 2036 analysis that applies the
method to the United States and Texas (2008-2024), estimates undocumented
populations for every state in 2024, and extends the approach to health-insurance
status. Draft materials are in [`draft-analysis/`](draft-analysis/):

- `undocumented_acs_residual_report.pdf` -- technical report
- `undocumented_acs_residual_deck.pdf` -- slide deck

These are drafts shared for transparency and reuse of the method; treat the
numbers as preliminary.

## References

- Warren, R., Warren, J.R., & Zheng, P. (2023). "A New Residual Approach for
  Estimating Undocumented Populations." *International Migration Review* 59(2):
  949-962. doi:10.1177/01979183231195280.
- Warren, R. (2014). "Democratizing Data about Unauthorized Residents in the
  United States." *Journal on Migration and Human Security* 2(4): 305-328.
- Passel, J.S., & Krogstad, J.M. (2025). *U.S. Unauthorized Immigrant Population
  Reached a Record 14 Million in 2023.* Pew Research Center.

## Citing

If you use the package, please cite Warren, Warren, and Zheng (2023) for the
method and this package as: Booth, E. (2026). *residualundoc: a Stata package for
residual-method estimation of the undocumented population.*

## Author and license

Eric Booth, Texas 2036 Data & Research (`eric.booth@texas2036.org`). Released
under the MIT License; see [LICENSE](LICENSE).
