# GTM Warehouse

The analytics layer over a go-to-market stack built from scratch — lead
sourcing, enrichment, buying signals, a sequencer, an inbound engine and
nurture — all running on Supabase and free tooling.

**17 models · 30 tests · runs on Postgres and BigQuery unchanged.**

This repo is the warehouse half. The operational pipelines that fill it live
in [gtm-inbound-engine](https://github.com/knife-co/gtm-inbound-engine) and
[gtm-signal-engine](https://github.com/knife-co/gtm-signal-engine).

---

## The shape of it

```
n8n + Supabase Edge Functions          collect
        │
        ▼
Supabase Postgres · public             operational store
        │   icp_companies · signals · router_decisions
        │   seq_* · inbound_* · mql_handoffs
        ▼
staging · views                        rename, cast, flag — no logic
        │
        ▼
intermediate · tables                  fix the grain: one row per company
        │
        ▼
marts · tables                         dim_accounts · dim_contacts
        │                              fct_outreach · fct_conversions
        ▼
analytics schema / dataset             warehouse output
        │
        ▼
GitHub Actions, 05:17 UTC daily        refresh + tests
```

## What it found

A warehouse that surfaces nothing is a warehouse nobody needed. These came out
of building it, and each one is written up in [docs/FINDINGS.md](docs/FINDINGS.md).

| | |
| --- | --- |
| **The funnel isn't a funnel** | The "signalled" stage is **190% of the stage before it**. A funnel stage can't exceed its parent — the signal collector and the ICP gate select companies independently, and nobody had noticed |
| **A join inflated 6 companies into 258 rows** | Two joins at the wrong grain, **43×**. No error, just a pipeline that looked forty-three times bigger than it was |
| **The pipeline had been coasting for three weeks** | 68 new companies in the first week, **9 across the next three**. Week one was a backfill of existing postings; the lump total hid it completely |
| **All three attribution models returned identical answers** | Correct, not broken: one channel and 83% single-day journeys mean first-touch, last-touch and linear *cannot* disagree |
| **The lead scoring has no measurable predictive power** | 20.0% vs 17.7%, **Fisher p = 0.67**. And the outcome it was designed to predict has never been measured |
| **The funnel caught itself lying** | It reported a join-coverage rate as a conversion rate. Found by re-deriving every number a second way, not by rereading the query |

## Grain, and why it's tested

A join at the wrong grain multiplies rows silently. The report then describes a
pipeline several times larger than the real one, with no error anywhere. That
happened here, and it's the single most expensive class of bug in analytics
because nothing announces it.

So the grain is asserted rather than assumed:

- `int_account_routing` collapses 357 router decisions over 44 accounts to one
  row per company — `unique` on `company_key`
- `int_company_signals` folds signal history to one row per company —
  `unique` on `company_key`
- `dim_accounts` joins three single-row-per-company tables and is itself
  `unique` on `company_key`

If any of them ever duplicates, `dbt test` fails and the build stops. The check
moved from *"if someone thinks to look"* to *"every single run"*.

Verified against live data: **442/442** distinct keys for `dim_accounts`,
41/41, 128/128 and 120/120 for the rest.

## The honest state of the data

| Mart | Rows | Real rows |
| --- | --- | --- |
| `dim_accounts` | 442 | 442 |
| `dim_contacts` | 41 | **0** |
| `fct_outreach` | 128 | **0** |
| `fct_conversions` | 120 | **0** |

Three of four marts describe work that has only ever run in test mode — a dry
run to my own addresses, and an inbound form built and then dropped.

`is_test` is carried as a column and **defaults to true**, so forgetting to
mark something undercounts real activity rather than inventing it. Any rate
over those tables filters `not is_test`, gets a denominator of zero, and
returns NULL.

**"Not measurable" and "0%" are different claims, and only one of them is
true.** This rule exists because an earlier reporting layer once reported a
confident 37.5% unsubscribe rate drawn entirely from that dry run.

## Running it

```bash
pip install dbt-core dbt-postgres     # add dbt-bigquery for the BigQuery target
cp profiles.example.yml ~/.dbt/profiles.yml   # then fill in your own values
dbt debug                              # connection only, touches no data
dbt run                                # 17 models
dbt test                               # 30 tests
dbt docs generate && dbt docs serve    # lineage graph
```

Switch warehouse with `--target bigquery`. No model changes — every model
reads through `source()` and `ref()`, so the only differences are a profile
entry and one line in `models/staging/_sources.yml`.

The daily refresh runs in GitHub Actions
([workflow](.github/workflows/daily-refresh.yml)) rather than on a laptop,
because a laptop is asleep at six in the morning. Three repository secrets
carry the connection; nothing secret is in the repo.

## Reading order

- **[docs/FINDINGS.md](docs/FINDINGS.md)** — the six findings, with the numbers
  and the methods
- **[docs/DECISIONS.md](docs/DECISIONS.md)** — what was chosen, what was
  rejected, and what was reversed after turning out to be wrong

## Caveats worth stating up front

- **The loader is manual.** Supabase → BigQuery is currently a CSV export, not
  a scheduled pipeline. Airbyte or a custom export job is the missing piece.
- **One table is in BigQuery so far.** The port is proven end to end; the
  remaining tables haven't been moved.
- **Small samples everywhere.** 442 companies and 0 real conversions. Every
  number here is reported with its sample size for that reason, and several
  analyses were abandoned rather than published at n=5.
