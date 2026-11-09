# residualundoc

A small Stata package for estimating the undocumented (unauthorized) immigrant
population with the residual method of Warren, Warren, and Zheng (2023). The
package implements the estimators in Booth (2026), and this README states each
equation next to the subcommand that computes it.

## The method in equations

Notation: `g` indexes geography, `t` indexes year, `a` indexes an anchor year.

**1. The residual identity.** The undocumented population is what remains after
subtracting the legal noncitizen population from the survey-measured noncitizen
population:

```
U(g,t) = C(g,t) - L(g,t)
```

`C` comes from the survey (typically ACS table B05001, adjusted upward for
undercount by the anchor source). `L` is a stock each source rolls forward from
administrative records: lawful admissions, naturalizations, deaths, and
emigration.

**2. The undocumented share of noncitizens.** Divide through by `C`:

```
theta(g,t) = U(g,t) / C(g,t) = 1 - L(g,t)/C(g,t)
```

Every component that moves `L` from one year to the next is a small fraction of
the stock, and `C` also changes gradually, so `theta` is slow-moving. Over
2010-2023 the Pew national series implies a `theta` drifting from 0.51 to 0.61,
about three-quarters of a percentage point a year. That smoothness is what makes
the whole approach work: if `theta` is known at a few points, its value nearby is
well approximated.

**3. The reduced-form estimator.** Set `theta` from a published anchor value `P`
at anchor year `a`, then multiply:

```
theta(g,a) = P(g,a) / C(g,a)
U_hat(g,t) = theta(g,t) * C(g,t)
L_hat(g,t) = C(g,t) - U_hat(g,t)
```

By construction `U_hat` reproduces the published value exactly at every anchor.
Between and beyond anchors it follows the observed survey count.
→ **`residualundoc interp`** (interpolates `theta` between anchor years).

**4. The cross-sectional application.** For a single year with only a national
anchor, apply one `theta` to every unit:

```
U_hat_RF(s) = theta_nat * C(s)
theta_nat   = sum_s P(s) / sum_s C(s)
```

Calibrating `theta_nat` to the sum of the published estimates makes the totals
match by construction, so the per-unit gap is purely the cost of assuming `theta`
is uniform across units. Agreement is summarized by the share of units within a
tolerance and by the index of dissimilarity:

```
D = 0.5 * sum_g |U_hat(g) - direct(g)| / sum_g direct(g)
```

`D` is the share of the total the single-`theta` shortcut assigns to the wrong
unit relative to the directly published estimates.
→ **`residualundoc apply`** (returns `r(theta)`, `r(dissimilarity)`, `r(within_tol)`).

**5. Rate transport on the odds scale.** To carry a survey-observable rate (for
example the ACS noncitizen uninsured rate `r_NC`) to the undocumented level, fix
a calibration constant at one anchor year where a benchmark rate `r_U(a)` is
published, then apply it to other years or places:

```
odds(r)    = r / (1 - r)
kappa      = odds(r_U(a)) / odds(r_NC(a))
r_hat_U(t) = kappa * odds(r_NC(t)) / (1 + kappa * odds(r_NC(t)))
```

and the counts follow as `U_unins = U_hat * r_hat_U` and
`U_ins = U_hat - U_unins`. The odds scale is used rather than a constant
multiplier because a multiplier can push a rate above 1; the odds transform stays
inside (0,1), treats the insured and uninsured shares symmetrically, and
reproduces the benchmark exactly at the anchor year.
→ **`residualundoc transport`** (`scale(odds|logit|ratio)`; `logit` is the same
algebra written additively, `ratio` is the unbounded version retained for
comparison).

**6. Direct year-by-year reconstruction.** Rather than borrowing `theta`, rebuild
`L` from its demographic parts and take the residual:

```
L(t)     = L(t-1) + arrivals(t) - naturalizations(t) - deaths(t) - emigration(t)
U_hat(t) = C(t) - L(t)
```

Emigration may be supplied directly, supplied as a rate applied to `L(t-1)`, or
derived so that `U_hat` hits published target values at given years, which is the
Warren et al. (2023) innovation of deriving emigration from observed survey
movement.
→ **`residualundoc direct`**.

**7. Sub-state and subgroup estimates.** The estimators operate on aggregated
counts, so ACS PUMS microdata enters as a data-prep step. Standard errors for
each cell use the Census successive-difference replication formula over the 80
replicate weights:

```
se(c) = sqrt( (4/80) * sum_i ( c_i - c_0 )^2 )
```

where `c_0` is the estimate from the full weight and `c_i` from replicate `i`.
→ tabulate cells, then feed them to **`apply`** and **`transport`** (see the PUMS
section below).

**A caution that applies throughout.** The reduced form inherits whatever the
anchor source embedded in its published number, including the undercount
adjustment and the emigration-and-coverage reconciliation. It does not re-derive
them, and it does not expose them between anchors. Composing the residual from
DHS administrative stocks instead yields roughly half the published totals,
because the administrative legal stock exceeds the survey-resident legal
population. Borrowing `theta` is the deliberate choice to inherit that
reconciliation rather than rebuild it.

## Install

Install from GitHub in Stata:

```stata
net install residualundoc, from("https://raw.githubusercontent.com/ericabooth/residualundoc-stata-public/main/") replace force
discard
which residualundoc
help residualundoc
```

To pull the worked example alongside the command, `net get` the ancillary do-file:

```stata
net get residualundoc, from("https://raw.githubusercontent.com/ericabooth/residualundoc-stata-public/main/")
do example_residualundoc.do
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

* Triangulation: published sources side by side with your own estimate;
* save() writes a .dta (or a CSV for any other extension), replace to rerun
residualundoc triangulate, year(2023) ///
    sources(Pew=14000000 CMS=12244500 MPI=13738000) workflow(14000000) ///
    save("triangulate_2023.dta", replace)
```

`apply` takes `moe()` (the ACS 90% margin of error) for a sampling interval,
`cilevel()` to change its level (default 90), and `srcrse()` to widen it into a
robustness band. `help residualundoc` lists the output variables each
subcommand creates: for example, `direct` adds `u_L`, `u_undoc`,
`u_emigration_used`, `u_arrivals_adj`, and `u_nc_adj`, and `transport` adds
`u_transported_rate` and `u_transported_kappa` (with the default prefix `u_`).

Run `example_residualundoc.do` for a self-contained tour of all five subcommands
plus the ACS PUMS integration pattern. It uses simulated data and needs no
Census API key or external download.

## Two ways to get a wrong answer

Both are easy to hit on new data, so the command now checks for them.

**Passing a share where a count belongs.** `anchors()` and `published()` take
published undocumented **counts**, not `theta` itself. Writing
`anchors(2023=0.61)` instead of `anchors(2023=14000000)` used to produce a
silent, near-zero estimate. `interp` now refuses that input with an explanatory
error rather than proceeding.

**An anchor that implies `theta` outside (0,1).** If the published count exceeds
the survey noncitizen count for that year and place, the identity
`U = C - L` with `L >= 0` cannot produce it. Both `interp` and `apply` now warn.
The usual cause is a geography or vintage mismatch between the anchor and the
survey series, for example pairing a multi-county anchor with a single-county
count.

One behavior that is intended but worth knowing: with a single anchor and the
default `tails(flat)`, `theta` is held constant at the anchor value and carried
across every year in the sample, so the estimate simply tracks the survey count.
That is a constant-ratio extrapolation, not an interpolation. Use `tails(linear)`
to extrapolate the trend instead, or `tails(missing)` to leave years outside the
anchor range empty.

## Estimation at smaller/lower levels of aggregation via PUMS published tables (ACS PUMS)

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
status. 

These are drafts shared for transparency and reuse of the method; treat the
numbers as preliminary.

## References

- Booth, E. (2026). "Estimating State Undocumented Populations from Published
  Survey Tables: A Reduced-Form Residual Method for Applied Policy Work."
  Working paper. The equations above are Sections 2, 4, and 7 of that paper.
- Warren, R., Warren, J.R., & Zheng, P. (2023). "A New Residual Approach for
  Estimating Undocumented Populations." *International Migration Review* 59(2):
  949-962. doi:10.1177/01979183231195280.
- Warren, R. (2014). "Democratizing Data about Unauthorized Residents in the
  United States." *Journal on Migration and Human Security* 2(4): 305-328.
- Passel, J.S., & Krogstad, J.M. (2025). *U.S. Unauthorized Immigrant Population
  Reached a Record 14 Million in 2023.* Pew Research Center.

## Citing

If you use the package, please cite Warren, Warren, and Zheng (2023) for the
method and this package as: 
Booth, Eric A. (2026). *residualundoc: a Stata package for residual-method estimation of the undocumented population.* 

The paper citation for this work is:
Booth, Eric A. (2026) "Estimating State Undocumented Populations from Published Survey Tables: A Reduced-Form Residual Method for Applied Policy Work" _Munich Personal RePEc Archive Paper No. 130290._ Available: https://mpra.ub.uni-muenchen.de/id/eprint/130290

## Changes

- **1.1.2 (2026-11-09):** `triangulate`'s `save()` picks the writer from the
  extension: a `.dta` name is saved as a Stata dataset (1.1.1 and earlier wrote
  CSV text into it, so `use` failed with r(610)), and any other name is written
  as CSV. The filename is quoted, so paths with spaces or accented characters
  work, and `save(filename, replace)` overwrites an existing file. `interp`
  returns `r(anchor_years)` and `r(anchor_values)` without a leading space, and
  an empty estimation sample stops with error 2000 and a plain message instead
  of an internal `ipolate` error. The help now lists the output variables of
  `direct` and `transport` and renders its subscripts as plain text.
- **1.1.1 (2026-11-09):** `bysort group: residualundoc interp ...`, which the
  help documents for panels, now works; 1.1.0 stopped with r(190) because the
  dispatcher was not byable. Under `by:`, the first group creates the output
  variables and later groups fill their own rows. `interp` also no longer reads
  across rows outside the estimation sample when it fills flat tails or
  `interpolate(nearest)`: with several groups in memory, the documented
  one-group-at-a-time `if` form left those years missing (in the worked
  example, U.S. 2024 under the Pew series and Texas 2015-2018 under the MPI
  series). The worked example no longer saves its temporary `us_row` marker
  into `example_residualundoc.dta` (it appeared there as `__000000`), and the
  dataset has been regenerated with the fixed `interp` code.

## Author and license

Eric A. Booth, Sr Researcher, Texas 2036 (eric.a.booth@gmail.com). Released
under the MIT License; see [LICENSE](LICENSE).
