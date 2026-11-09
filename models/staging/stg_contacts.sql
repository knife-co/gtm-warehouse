{{ config(materialized='view') }}
select
    id              as contact_id,
    email,
    lower(split_part(email, '@', 2)) as email_domain,
    first_name,
    company         as company_name_raw,
    source,
    created_at
from {{ source('gtm', 'seq_contacts') }}
