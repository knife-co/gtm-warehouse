-- test_mode defaults to TRUE when unknown. Forgetting to mark something
-- produces an undercount of real activity, never a fabricated result.
{{ config(materialized='view') }}
select
    id              as campaign_id,
    name            as campaign_name,
    coalesce(test_mode, true) as is_test,
    active          as is_active,
    cohort,
    created_at
from {{ source('gtm', 'seq_campaigns') }}
