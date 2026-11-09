-- company_key stays nullable on purpose: 62% of signals cannot be resolved
-- to a company, and filtering that away here would quietly shrink every
-- number downstream.
{{ config(materialized='view') }}
select
    id              as signal_id,
    signal_type,
    company_key,
    company_key is not null as is_resolvable,
    detected_at
from {{ source('gtm', 'signals') }}
