{smcl}
{* *! version 1.1.0  2026-07-03}{...}
{title:Title}

{p2colset 5 26 26 2}{...}
{p2col :{cmd:residualundoc} {hline 2}}Residual-method estimator of the undocumented population.{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 16 2}
{cmd:residualundoc} [{it:subcommand}] [{it:varlist}] [{help if:{it:if}}] [{help in:{it:in}}] [{cmd:,} {it:options}]

{synoptset 24 tabbed}{...}
{synopthdr:subcommand}
{synoptline}
{synopt:{opt interp}}anchor-interpolation over time (default){p_end}
{synopt:{opt apply}}cross-sectional: one theta across units, with an optional benchmark vs a direct estimate{p_end}
{synopt:{opt direct}}Warren-style direct year-by-year residual construction{p_end}
{synopt:{opt transport}}odds- or logit-scale rate transport to a benchmark anchor{p_end}
{synopt:{opt triangulate}}side-by-side comparison of residual-method sources at a year{p_end}
{synoptline}

{p 4 6 2}
If no subcommand is given, {cmd:interp} is assumed.


{title:Description}

{pstd}
{cmd:residualundoc} implements a family of residual-method estimators of the
undocumented (unauthorized) immigrant population, following
{help residualundoc##W2023:Warren, Warren, & Zheng (2023)}. The residual
identity is

{p 8 12 2}
{it:U}{sub:{it:t}} = {it:C}{sub:{it:t}} - {it:L}{sub:{it:t}}

{pstd}
where {it:C}{sub:{it:t}} is survey-measured noncitizens (typically the ACS
{it:not a U.S. citizen} category, adjusted for survey undercount) and
{it:L}{sub:{it:t}} is the legal noncitizen population reconstructed
year-by-year from administrative data (DHS lawful admissions, naturalizations,
life-table mortality, and derived-from-ACS emigration).

{pstd}
Because {it:L}{sub:{it:t}} moves slowly, the ratio

{p 8 12 2}
{it:theta}{sub:{it:t}} = {it:U}{sub:{it:t}} / {it:C}{sub:{it:t}} = 1 - {it:L}{sub:{it:t}} / {it:C}{sub:{it:t}}

{pstd}
is a slow-moving demographic quantity. Different reputable residual-method
implementations (Pew, MPI, and CMS) publish {it:U}{sub:{it:t}} for specific
years and geographies; each implicitly pins {it:theta} at those years.
{cmd:residualundoc interp} imports {it:theta} from a residual-method source
at anchor years, linearly interpolates between them, and computes
{it:U-hat}{sub:{it:t}} = {it:theta}{sub:{it:t}} * {it:C}{sub:{it:t}}. This
reproduces the source's published values exactly at anchor years and lets ACS
noncitizen movement carry between-anchor and beyond-anchor variation.

{pstd}
{cmd:residualundoc apply} is the cross-sectional counterpart: it applies a single
{it:theta} to every unit (for example, every state) in one year, computing
{it:U-hat}{sub:{it:g}} = {it:theta} * {it:C}{sub:{it:g}}. If a directly published
("direct") residual estimate is supplied for each unit, it reports where the
single-{it:theta} shortcut agrees and where it misses: the share of units within a
tolerance of the direct estimate and an index of dissimilarity (the share of the
total the shortcut assigns to the wrong unit). Calibrating {it:theta} to the sum
of the direct estimates makes the totals match by construction, so the per-unit
gap isolates the cost of assuming {it:theta} is uniform across units.

{pstd}
{cmd:residualundoc direct} instead implements the year-by-year Warren
accounting when the user supplies DHS-based arrivals, naturalizations, and
deaths, plus either an emigration series or one or more residual-method
{it:U}-anchors from which to derive emigration. This is closer to the
literal Warren et al. (2023) construction and is intended for users with
DHS Yearbook and life-table inputs.

{pstd}
{cmd:residualundoc transport} calibrates a survey-measured rate (for example,
the ACS noncitizen uninsured rate) to a residual-method benchmark rate at one
anchor year, transporting on the odds, logit, or ratio scale.

{pstd}
{cmd:residualundoc triangulate} reports the range of residual-method estimates
from several sources at one year for a quick sensitivity check.


{marker interp}{...}
{title:Subcommand: interp}

{p 8 16 2}
{cmd:residualundoc} [{cmd:interp}] {it:yearvar} {it:noncitizensvar} [{it:if}] [{it:in}]{cmd:,}
{opth anch:ors(string)} [ {opt sourcename(name)}
{opth pop(varname)} {opth int:erpolate(name)} {opth ta:ils(name)}
{opt gen:erate(prefix)} {opt rep:lace} ]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth anch:ors(string)}}Required. Space-separated {it:year}={it:value} pairs, e.g.
{cmd:anchors(2010=11400000 2015=11000000 2023=14000000)}.{p_end}
{synopt:{opt sourcename(name)}}Label attached to variable descriptions and returned in
{cmd:r(anchor_source)}. Default {cmd:anchor}.{p_end}
{synopt:{opth pop(varname)}}Total-population variable. Adds {it:prefix}{cmd:pct_pop}.{p_end}
{synopt:{opth int:erpolate(name)}}{cmd:linear} (default), {cmd:logit}, or {cmd:nearest}.{p_end}
{synopt:{opth ta:ils(name)}}{cmd:flat} (default), {cmd:linear}, or {cmd:missing}. Controls
behavior for years outside the anchor range.{p_end}
{synopt:{opt gen:erate(prefix)}}Prefix for output variables (default {cmd:u_}).{p_end}
{synopt:{opt rep:lace}}Overwrite prior output variables with the same prefix.{p_end}
{synoptline}

{pstd}
Output variables added to the data (using default prefix {cmd:u_}):

{synoptset 24 tabbed}{...}
{synopt:{cmd:u_theta}}Interpolated theta_t.{p_end}
{synopt:{cmd:u_undoc}}Estimated undocumented population, U_hat_t = theta_t * NC_t.{p_end}
{synopt:{cmd:u_lawful}}Residual legal noncitizens, NC_t - U_hat_t.{p_end}
{synopt:{cmd:u_published}}Published anchor value at anchor rows (else missing).{p_end}
{synopt:{cmd:u_at_anchor}}1 if the year is an anchor.{p_end}
{synopt:{cmd:u_pct_pop}}U_hat_t / pop, if {opt pop()} supplied.{p_end}
{synoptline}

{pstd}
For a panel with multiple groups, run once per group (via {cmd:if}) or use
{cmd:bysort {it:group}: residualundoc interp ...}.


{marker apply}{...}
{title:Subcommand: apply}

{p 8 16 2}
{cmd:residualundoc apply} {it:noncitizensvar} [{it:if}] [{it:in}]{cmd:,}
( {opt theta(#)} | {opth pub:lished(varname)} | {opth dir:ect(varname)} )
[ {opt gen:erate(prefix)} {opt tol:erance(#)} {opth moe(varname)}
{opt src:rse(# | varname)} {opt cil:evel(#)} {opt rep:lace} ]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt theta(#)}}Supply {it:theta} directly (a share in 0-1).{p_end}
{synopt:{opth pub:lished(varname)}}Calibrate {it:theta} = sum({it:published}) / sum({it:noncitizens}) over the sample.{p_end}
{synopt:{opth dir:ect(varname)}}A per-unit direct estimate: calibrate {it:theta} to its sum {it:and} benchmark each unit against it.{p_end}
{synopt:{opt gen:erate(prefix)}}Prefix for output variables (default {cmd:u_}).{p_end}
{synopt:{opt tol:erance(#)}}Percent tolerance for the "within" diagnostic (default 10).{p_end}
{synopt:{opth moe(varname)}}ACS 90% margin of error on the noncitizen count; adds an ACS sampling confidence interval on {it:U-hat}.{p_end}
{synopt:{opt src:rse(# | varname)}}Optional source-spread relative SE that WIDENS the sampling interval into a robustness band (not a formal CI); reporting the source min-max range separately is usually preferable.{p_end}
{synopt:{opt cil:evel(#)}}Confidence level for the interval (default 90).{p_end}
{synopt:{opt rep:lace}}Overwrite prior output variables with the same prefix.{p_end}
{synoptline}

{p 4 6 2}
Give exactly one of {opt theta()}, {opt published()}, or {opt direct()}.

{pstd}
Output variables (default prefix {cmd:u_}): {cmd:u_undoc} always; when
{opt direct()} is given, {cmd:u_diff} ({it:U-hat} minus direct) and {cmd:u_pct}
(percent difference); and when {opt moe()} is given, {cmd:u_moe}, {cmd:u_lo}, and
{cmd:u_hi} (the ACS sampling confidence interval, widened to a robustness band
if {opt srcrse()} is given; no undercount). Stored results: {cmd:r(theta)}, {cmd:r(n_units)};
with {opt direct()}, {cmd:r(dissimilarity)}, {cmd:r(within_tol)},
{cmd:r(within_share)}, {cmd:r(tolerance)}; with {opt moe()}, {cmd:r(cilevel)}.


{marker direct}{...}
{title:Subcommand: direct}

{p 8 16 2}
{cmd:residualundoc direct} {it:yearvar} {it:noncitizensvar} [{it:if}] [{it:in}]{cmd:,}
{opth ar:rivals(varname)} {opth na:tz(varname)} {opth de:aths(varname)}
{opt l0(#)} [ {opth em:igration(varname)} {opt asrate}
{opth under:count(varname)} {opt targ:etu(spec)} {opt gen:erate(prefix)} {opt rep:lace} ]

{pstd}
Roll {it:L}{sub:{it:t}} forward each year:

{p 8 12 2}
{it:L}{sub:{it:t}} = {it:L}{sub:{it:t}-1} + arrivals - natz - deaths - emigration

{pstd}
Emigration is either supplied (a count series, or a rate with {opt asrate}),
or {it:derived} so that {it:U}{sub:{it:t}} equals a target value in one or
more anchor years (Warren's "derive emigration from ACS" innovation, generalized
here to any year with a published residual-method anchor). If neither is given,
emigration is treated as zero and a note is printed.

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth ar:rivals(varname)}}Required. Immigrant + refugee + asylee + adjusted nonimmigrant arrivals in year t.{p_end}
{synopt:{opth na:tz(varname)}}Required. Naturalizations in year t.{p_end}
{synopt:{opth de:aths(varname)}}Required. Deaths of legal noncitizens in year t (life-table method).{p_end}
{synopt:{opt l0(#)}}Required. Starting {it:L}{sub:{it:t}0} in the first year of the touse subset.{p_end}
{synopt:{opth em:igration(varname)}}Optional emigration series (count or rate; use {opt asrate}).{p_end}
{synopt:{opt asrate}}Interpret {opth em:igration()} as a rate on the prior year's {it:L}.{p_end}
{synopt:{opth under:count(varname)}}Rate by which arrivals and {it:C} are inflated (e.g., 0.072 for 7.2%).{p_end}
{synopt:{opt targ:etu(spec)}}Space-separated {it:year}={it:U-target} pairs to derive emigration
so {it:U-hat} hits the target(s).{p_end}
{synoptline}


{marker transport}{...}
{title:Subcommand: transport}

{p 8 16 2}
{cmd:residualundoc transport} {it:ratevar} [{it:if}] [{it:in}]{cmd:,}
{opt anch:or(year value)} [ {opth ye:ar(varname)}
{opth sc:ale(name)} {opt gen:erate(prefix)} {opt rep:lace} ]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt anch:or(year value)}}Required. Anchor year and target rate (in 0-1).
Example: {cmd:anchor(2023 0.664)}.{p_end}
{synopt:{opth ye:ar(varname)}}Numeric year variable; defaults to a variable named {cmd:year}.{p_end}
{synopt:{opth sc:ale(name)}}{cmd:odds} (default), {cmd:logit}, or {cmd:ratio}.{p_end}
{synoptline}

{pstd}
Odds- and logit-scale transports are algebraically equivalent and keep the
transported rate in (0, 1). The ratio scale is retained for comparison but
often saturates at 1 for high baseline rates.


{marker triangulate}{...}
{title:Subcommand: triangulate}

{p 8 16 2}
{cmd:residualundoc triangulate}{cmd:,}
{opt ye:ar(#)} {opt so:urces(spec)} [ {opth work:flow(#)} {opt sa:ve(filename)} ]

{pstd}
Prints a name-and-value table of residual-method estimates at a single year,
plus the min/max spread; optionally overlays your own workflow's value and
flags whether it is inside the source range.


{marker pums}{...}
{title:Integrating ACS PUMS microdata}

{pstd}
The estimator operates on aggregated counts, so person-level ACS PUMS enters as a
data-preparation step rather than a separate subcommand. To disaggregate below the
published tables (by age, origin, year of entry, or sub-state area), tabulate the
survey noncitizen counts by cell from the PUMS person file, then feed those counts
to {cmd:apply} and {cmd:transport}. Use the 80 replicate weights for standard
errors via successive-difference replication, which is the variance method the
Census Bureau supplies for this file:

{phang2}
. {cmd:import delimited using psam_p48.csv, clear}    {it:(the ACS person PUMS)}{p_end}
{phang2}
. {cmd:gen byte noncit = (cit == 5)}{p_end}
{phang2}
. {cmd:gen byte unins  = (hicov == 2)}{p_end}
{phang2}
. {cmd:svyset [pw=pwgtp], sdrweight(pwgtp1-pwgtp80) vce(sdr)}{p_end}
{phang2}
. {cmd:svy: total noncit, over(agegroup)}    {it:(noncitizen counts + replicate-weight SEs)}{p_end}

{pstd}
Collapse the weighted noncitizen counts (and the noncitizen uninsured rate) to the
cell level, then apply {it:theta} and transport the rate:

{phang2}
. {cmd:collapse (sum) nc_w ncun_w, by(agegroup)}{p_end}
{phang2}
. {cmd:gen double noncit_count = nc_w}{p_end}
{phang2}
. {cmd:gen double nc_unins_rate = ncun_w / nc_w}{p_end}
{phang2}
. {cmd:residualundoc apply noncit_count, theta(0.62) generate(cell_)}{p_end}
{phang2}
. {cmd:residualundoc transport nc_unins_rate, year(year) anchor(2024 0.66) generate(cell_ins_)}{p_end}

{pstd}
The undocumented-count standard error is {it:theta} times the noncitizen-count
standard error from {cmd:svy: total}; carry it through for cell-level uncertainty.
Detail and uncertainty grow together, so this path is worth it for a subgroup or
sub-state number and not for a statewide total the tables already pin down. See
Section 5b of {cmd:example_residualundoc.do} for a runnable version on simulated
microdata.


{marker examples}{...}
{title:Examples}

{pstd}
Interpolate a Pew U.S. anchor series across an ACS panel:{p_end}
{phang2}
. {cmd:use acs_us, clear}{p_end}
{phang2}
. {cmd:residualundoc interp year noncitizen_total, ///}{p_end}
{phang2}{cmd:    anchors(2010=11400000 2015=11000000 2017=10500000 2019=10200000 2021=10500000 2022=11800000 2023=14000000) ///}{p_end}
{phang2}{cmd:    sourcename(Pew) pop(pop_total) generate(u_pew_)}{p_end}

{pstd}
Interpolate an MPI Texas anchor series with only two anchors and flat tails:{p_end}
{phang2}
. {cmd:residualundoc interp year noncitizen_total if geo=="Texas", ///}{p_end}
{phang2}{cmd:    anchors(2019=1739000 2023=1966000) sourcename(MPI) generate(u_mpi_)}{p_end}

{pstd}
Apply one national theta across states in 2024 and benchmark against CMS's direct
state estimates (theta calibrated to the CMS national total):{p_end}
{phang2}
. {cmd:residualundoc apply noncitizen_total, direct(cms_direct) tolerance(10) generate(rf_)}{p_end}
{phang2}
. {cmd:di r(theta), r(dissimilarity), r(within_tol)}{p_end}

{pstd}
Transport the ACS noncitizen uninsured rate to MPI's 66.4% Texas benchmark:{p_end}
{phang2}
. {cmd:residualundoc transport noncitizen_uninsured_rate if geo=="Texas", ///}{p_end}
{phang2}{cmd:    anchor(2023 0.664) scale(odds) generate(u_ins_)}{p_end}

{pstd}
Compare Pew, CMS, and MPI 2023 U.S. estimates against your workflow value:{p_end}
{phang2}
. {cmd:residualundoc triangulate, year(2023) sources(Pew=14000000 CMS=12244500 MPI=13738000) workflow(14000000)}{p_end}


{title:Stored results}

{pstd}
{cmd:residualundoc interp} stores in {cmd:r()}:

{synoptset 22 tabbed}{...}
{synopt:{cmd:r(N_anchors)}}number of anchor rows placed{p_end}
{synopt:{cmd:r(anchor_years)}}space-separated anchor years{p_end}
{synopt:{cmd:r(anchor_values)}}space-separated anchor values{p_end}
{synopt:{cmd:r(anchor_source)}}source label from {opt sourcename()}{p_end}
{synopt:{cmd:r(interp)}}interpolation method used{p_end}
{synopt:{cmd:r(tails)}}tail rule used{p_end}
{synoptline}

{pstd}
{cmd:residualundoc apply} stores {cmd:r(theta)}, {cmd:r(n_units)}, and, when
{opt direct()} is given, {cmd:r(dissimilarity)}, {cmd:r(within_tol)},
{cmd:r(within_share)}, and {cmd:r(tolerance)}.

{pstd}
{cmd:residualundoc transport} stores {cmd:r(kappa)}, {cmd:r(anchor_year)},
{cmd:r(anchor_value)}, and {cmd:r(scale)}.

{pstd}
{cmd:residualundoc triangulate} stores {cmd:r(min)}, {cmd:r(max)},
{cmd:r(spread_pct)}, {cmd:r(N_sources)}, and (if given) {cmd:r(workflow)}.


{title:Definitions and boundaries}

{pstd}
Throughout, "undocumented" and "unauthorized" are interchangeable and follow
the residual-method literature's definition, which includes people with
temporary or liminal legal protections (DACA, Temporary Protected Status,
humanitarian parole, and pending asylum). Pew reports that more than 40
percent of the 2023 unauthorized population held some protection from
deportation, and CMS reports that liminal-status immigrants were more than
a third of its 2024 total. The program does not itself impute individual
legal status; it works from aggregated survey and administrative inputs.

{pstd}
The interpolation is on {it:theta}, not on the {it:count}. This preserves
the residual identity at anchor years and lets ACS noncitizen movement carry
the between-anchor variation. If a caller wants to fix {it:U} at anchor years
but interpolate the raw count across years, that is not what this command
does; use {help ipolate} on the count directly.

{pstd}
"CMS" in the residual-methods literature refers to the Center for Migration
Studies of New York ({browse "https://cmsny.org/":cmsny.org}), an immigration
research institute. It is not the Centers for Medicare & Medicaid Services.


{marker references}{...}
{title:References}

{marker W2023}{...}
{p 4 8 2}
Warren, R., Warren, J. R., & Zheng, P. (2023). A new residual approach for
estimating undocumented populations. {it:International Migration Review},
59(2), 949-962.
{browse "https://doi.org/10.1177/01979183231195280":doi:10.1177/01979183231195280}.

{p 4 8 2}
Warren, R. (2014). Democratizing data about unauthorized residents in the
United States: Estimates and public-use data, 2010 to 2013. {it:Journal on
Migration and Human Security}, 2(4), 305-328.

{p 4 8 2}
Passel, J. S., & Krogstad, J. M. (2025). U.S. unauthorized immigrant
population reached a record 14 million in 2023. Pew Research Center.
{browse "https://www.pewresearch.org/race-and-ethnicity/2025/08/21/":pewresearch.org}.

{p 4 8 2}
Migration Policy Institute. {it:Profile of the Unauthorized Population: Texas}.
{browse "https://www.migrationpolicy.org/data/unauthorized-immigrant-population/state/tx":migrationpolicy.org}.


{title:Author}

{pstd}
Eric Booth, Texas 2036 Data & Research. Report issues by email:
{browse "mailto:eric.booth@texas2036.org":eric.booth@texas2036.org}.


{title:Also see}

{p 4 13 2}
Online: {help ipolate}, {help logit()}, {help getcensus} (if installed)
