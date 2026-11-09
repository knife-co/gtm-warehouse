-- One row per contact in the sequencer.
-- Caveat worth knowing: all 41 contacts sit on 4 email domains, because the
-- only campaign run so far was a dry run to the author's own addresses.
{{ config(materialized='table') }}

with enrolments as (
    select
        contact_id,
        count(*)                  as enrollment_count,
        min(enrolled_at)          as first_enrolled_at,
        max(enrolled_at)          as last_enrolled_at,
        bool_or(enrollment_status = 'active') as has_active_enrollment
    from {{ ref('stg_enrollments') }}
    group by contact_id
),

test_flag as (
    -- a contact is "real" only if some campaign they were enrolled in was not test
    select en.contact_id, bool_and(cp.is_test) as is_test
    from {{ ref('stg_enrollments') }} en
    join {{ ref('stg_campaigns') }} cp on cp.campaign_id = en.campaign_id
    group by en.contact_id
)

select
    k.contact_id,
    k.email,
    k.email_domain,
    k.first_name,
    k.company_name_raw,
    k.source,
    k.created_at,
    coalesce(e.enrollment_count, 0) as enrollment_count,
    e.first_enrolled_at,
    e.last_enrolled_at,
    coalesce(e.has_active_enrollment, false) as has_active_enrollment,
    coalesce(t.is_test, true)       as is_test
from {{ ref('stg_contacts') }} k
left join enrolments e on e.contact_id = k.contact_id
left join test_flag  t on t.contact_id = k.contact_id
