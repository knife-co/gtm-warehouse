-- The router writes a decision per account per daily run (357 rows over 44
-- accounts). This collapses that to ONE ROW PER COMPANY - the latest decision -
-- so dim_accounts can join to it without multiplying rows.
{{ config(materialized='table') }}

select distinct on (company_key)
    company_key,
    tier            as latest_tier,
    priority        as latest_priority,
    signal_score    as latest_signal_score,
    decided_at      as last_decided_at
from {{ ref('stg_router_decisions') }}
where company_key is not null
order by company_key, decided_at desc
