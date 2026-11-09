# Findings

Six things building this warehouse surfaced. Each has the number, the method,
and the sample size. Where a finding was wrong, the correction is here too.

---

## 1. The funnel is not a funnel

| # | Stage | Companies | % of previous | Measurable |
| --- | --- | --- | --- | --- |
| 1 | Sourced | 442 | — | yes |
| 2 | Scored | 442 | 100.0% | yes |
| 3 | Gate passed | 40 | 9.0% | yes |
| 4 | Signalled | 77 | **192.5%** | yes |
| 5 | Good fit **and** signalled | 7 | 9.1% | yes |

A funnel stage cannot be larger than the one above it. This one is, which
means stage 4 isn't drawn from stage 3 at all.

**The ICP gate and the signal collector select companies independently.** Forty
companies passed the fit gate; 77 have signals; only 7 are both.

Checked for a null artifact — there isn't one: 402 companies are explicitly
`false`, 40 explicitly `true`, none null.

The rates settle it. Signal coverage is **17.5%** of gate-passed companies
(7/40) and **17.2%** of rejected ones (69/402). Statistically identical. The
collector isn't biased toward poor-fit companies; the gate simply isn't an
input to it.

**Consequence:** 69 rejected companies are being monitored, and 33 of the 40
genuine fits are watched by nothing.

---

## 2. A join inflated six companies into 258 rows

| Stage | Naive row count | True companies | Inflation |
| --- | --- | --- | --- |
| Signalled | 149 | 76 | 2.0× |
| Routed | 39 | 6 | 6.5× |
| Both joins at once | **258** | **6** | **43×** |

Nothing errors. The report simply says the pipeline is forty-three times larger
than it is.

This is kept as a model (`p7_funnel_naive`, in the operational repo) rather
than described, so the trap stays reproducible. The `unique` tests on the
intermediate models exist specifically to make this class of bug fail the
build.

---

## 3. The pipeline had been coasting for three weeks

Cohorting by acquisition date was impossible — all 442 companies share one
`created_at`, because they were loaded in a single batch. Re-aimed at the week
each company's **first signal** fired, which does vary.

| Cohort week | New companies | Good fit | Signals | Routed |
| --- | --- | --- | --- | --- |
| 12 Oct | 68 | 7 | 142 | 6 |
| 19 Oct | 6 | 0 | 9 | 0 |
| 26 Oct | 1 | 0 | 1 | 0 |
| 2 Nov | 2 | 0 | 2 | 0 |

68 companies in week one, nine across the following three. Week one was a
backfill of job postings that already existed; everything after is the live
rate, which is roughly **one new company per week**. Nothing found after that
first week has been routed.

The lump figure — "77 companies with signals" — hides this completely.
Separating a backfill from an ongoing rate is exactly what cohort analysis is
for, and it's the first time this was visible.

---

## 4. All three attribution models returned identical answers

| Signal type | Touches | First-touch | Last-touch | Linear |
| --- | --- | --- | --- | --- |
| `gtm_hire` | 11 | 6.000 | 6.000 | 6.000 |

Not a bug. The validity check reports why: **one channel, 6 conversions, 11
touches, 4 of 6 companies single-touch, and 83.3% of journeys spanning a single
day.**

First-touch, last-touch and linear can only disagree when credit has somewhere
else to go. With one channel and same-day journeys, they are mathematically
forced to agree.

This is a better outcome than a tidy attribution chart would have been. The
models are correct, they ran on real data, and they demonstrate the
precondition for the entire first-touch-versus-last-touch argument that
marketing and sales teams have constantly.

No attribution conclusion is claimed anywhere, because none is available.

---

## 5. The lead scoring has no measurable predictive power

A backtest of the Month-1 ICP weights against the only **non-circular** outcome
available.

| | Rate | Wilson 95% CI |
| --- | --- | --- |
| Scored (`icp_score > 0`) | 8/40 = **20.0%** | [10.5%, 34.8%] |
| Rejected (`icp_score = 0`) | 71/402 = **17.7%** | [14.2%, 21.7%] |

Difference **+2.3 points**. Fisher exact two-sided **p = 0.669**, odds ratio
1.17. The intervals overlap almost entirely.

**On the choice of outcome:** routing can't be used, because the router takes
`icp_score` as an input — high scores get routed by construction. Signal
occurrence is the only observable outcome the score doesn't feed into.

**On the per-band rates:** they were computed and discarded. The bands hold 5,
5, 8 and 22 companies, and their confidence intervals are 31 to 65 percentage
points wide. The apparent pattern is noise, and publishing it would be
inventing a finding.

**The deeper problem.** The score was built to predict *fit for outreach* —
whether a company would reply. That outcome does not exist in the data, because
no real outreach was ever sent. So the honest position is three-part: the score
doesn't predict signals, it was never designed to, and the thing it *was*
designed to predict has never been measured.

---

## 6. The funnel caught itself reporting a false number

The first version reported **"77 signalled → 6 routed = 7.9%"** as a conversion
rate. It is not one.

| Table | Rows | With `company_key` | % keyed | Real entities | Traceable to ICP |
| --- | --- | --- | --- | --- | --- |
| signals | 389 | 149 | 38.3% | 162 | 76 |
| router_decisions | 317 | 39 | **12.3%** | 44 | **6** |
| outreach_targets | 27 | 5 | 18.5% | 27 | 5 |

The router keys accounts as `board:greenhouse:cloudflare` — the ATS board, a
different entity space from the ICP list. It holds 44 accounts; six happen to
carry a matching key.

So 7.9% measures **how far the join keys reach**, not how many companies
converted. Same class of error as a 37.5% unsubscribe rate reported earlier
from a dry run: a clean, plausible number with nothing behind it.

Caught by re-deriving every figure by a second route, not by rereading the
query. The fix marks those stages `measurable = false`, returns no percentage
at all, and adds a coverage model so the join gap is visible rather than
silently shrinking every downstream number.

---

## A finding that was wrong, and the correction

Finding 1 was first written up as: *the collector ignores the ICP gate, so
gating it would cut ~90% of wasted collection work.*

Checked before acting:

| Signal type | Total | From gate-passed | From gate-failed | From unmatched |
| --- | --- | --- | --- | --- |
| `gtm_hire` | 414 | **22** | 128 | 264 |
| `tool_added` | 7 | **0** | 7 | 0 |

**Every `tool_added` signal came from a company the gate rejected.** Gating the
collector would have retired that signal type permanently and cut total signals
from 421 to 22 — a 95% reduction, on a pipeline already producing one or two
companies a week.

`gate_passed` means *worth emailing*. The collector asks *is anything happening
here*. Different questions, so the two systems being separate is defensible,
not the bug it was called.

The real gap is the reverse: of 40 good-fit companies, only **15 have a valid
ATS board**, 8 have ever produced a signal, and 6 are invisible to every
collector. Board discovery is token guessing at a **5.5–7.1% hit rate** against
three ATSs, and a miss is permanent — 202 `not_found` rows were checked once
and never retried.

Diagnosed, not yet fixed.
