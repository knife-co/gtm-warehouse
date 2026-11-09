# Decisions

What was chosen, what was rejected, and what was reversed. Dated, because
several of these overturn an earlier call.

---

## Staging does no business logic (4 Nov)

**Decision.** Staging models rename, cast and flag. No joins, no aggregation,
no rules. Everything downstream starts from clean, predictable columns.

**Why.** Mixing cleaning with logic means every later model inherits both, and
a change to either one risks the other. It also makes the grain impossible to
reason about, which is where the expensive bugs live.

**Cost.** More models. Eleven staging views for eleven source tables is a lot
of files that each do very little, and that is the correct trade.

---

## `company_key` stays nullable in `stg_signals` (4 Nov)

**Decision.** 62% of signals cannot be resolved to a company. Staging keeps
them, with an `is_resolvable` flag, rather than filtering them out.

**Why.** A filter here would silently shrink every number downstream, and the
62% would never appear in any report. Carrying the flag makes the gap
countable; `int_company_signals` filters on it explicitly, where the decision
is visible.

---

## Two intermediate models exist only to fix the grain (6 Nov)

**Decision.** `int_account_routing` and `int_company_signals` do nothing but
collapse many rows to one row per company, each guarded by a `unique` test.

**Why.** `dim_accounts` joins three tables. If any right-hand side holds more
than one row per company, the join multiplies and the mart reports a pipeline
several times larger than reality — with no error. This happened: two joins
over six companies produced 258 rows.

The intermediates exist so the fan-out is impossible by construction, and the
`unique` tests exist so that if it ever becomes possible again, the build fails
instead of the report lying.

---

## `is_test` defaults to true (6 Nov)

**Decision.** Every test flag defaults to `true` where unknown, not `false`.

**Why.** Forgetting to mark something produces an **undercount of real
activity**, never a fabricated result. The reverse default means an unmarked
test row is silently counted as real, which is how a dry run to one's own
addresses becomes a 37.5% unsubscribe rate in a report.

---

## A rate with nothing behind it is NULL, never 0% (31 Oct, carried forward)

**Decision.** Every rate over a zero denominator returns NULL and the verdict
"not measurable".

**Why.** An empty funnel is unknown, not zero per cent. Reporting 0% invites
someone to read it as a measured result and act on it.

---

## The scheduler is GitHub Actions, not the laptop (6 Nov)

**Decision.** The daily refresh runs in CI at 05:17 UTC.

**Why.** dbt Core runs on a machine, and a laptop is asleep at six in the
morning. The free options for scheduling dbt Core are GitHub Actions or a paid
dbt Cloud seat.

**Detail.** The cron is `17 5 * * *`, not `0 5 * * *`. Everything in the world
scheduled at `:00` queues behind everything else scheduled at `:00`.

---

## Postgres first, BigQuery second (4 Nov)

**Decision.** The warehouse layer was built on Postgres and ported to BigQuery
afterwards, rather than starting on BigQuery as originally planned.

**Why.** The BigQuery **sandbox** — the free, no-credit-card tier — does not
support DML statements, which means dbt's `incremental` materialization cannot
run there at all. One of the three materializations worth learning was
unavailable. Sandbox tables also expire after 60 days.

**What it proved.** Porting turned out to be a profile entry plus one line in
`_sources.yml`, with no model changes. Doing it in that order demonstrated
dbt's portability better than starting on BigQuery would have.

---

## Seeds are not the loader (9 Nov)

**Decision.** Data reaches BigQuery by CSV upload for now. `dbt seed` was
tried and abandoned.

**Why.** Seeds are for small static reference data and dbt enforces a 1 MiB
limit, which the export exceeded at 3.67 MB. More importantly, seeds are a
snapshot, not a pipeline — a production Supabase → BigQuery path is a scheduled
job (Airbyte, Fivetran, or a custom export).

**Stated rather than implied.** The current loader is manual. Calling it a
pipeline would be overclaiming.

---

## Gating the signal collector on the ICP gate — rejected (6 Nov)

**Decision.** Rejected, after it had already been recommended.

**Why the reversal.** The proposal was to feed `gate_passed` into the collector
and cut ~90% of collection work. Checking it first: **all 7 `tool_added`
signals came from gate-rejected companies**, and total signals would have
fallen from 421 to 22.

`gate_passed` answers *worth emailing*. The collector answers *is anything
happening here*. Conflating them would have switched off most of a pipeline
that was already producing very little.

**What replaced it.** The real gap is coverage of the good-fit companies, not
exclusion of the rest. See FINDINGS.md.

---

## Per-band backtest rates computed and discarded (9 Nov)

**Decision.** The ICP score backtest reports a single scored-vs-rejected
comparison. The per-band rates were computed and left out.

**Why.** The bands hold 5, 5, 8 and 22 companies. Their 95% confidence
intervals are 31 to 65 percentage points wide. One band shows 40% and another
0%, and both are noise.

Publishing them would have produced a chart that looked like a finding and was
not one. The single comparison, with its p-value and its interval, is the most
that sample supports.
