{{ config(materialized='view') }}
select
    id              as submission_id,
    received_at,
    email,
    email_domain,
    status          as submission_status,
    honeypot_hit,
    ack_status,
    ack_sent_at,
    enrich_status,
    processed_at,
    coalesce(is_test, true) as is_test
from {{ source('gtm', 'inbound_submissions') }}
