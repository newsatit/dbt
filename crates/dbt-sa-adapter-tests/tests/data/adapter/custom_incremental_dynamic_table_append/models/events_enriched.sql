{{ config(
    materialized='dynamic_table',
    snowflake_warehouse='FUSION_SLT_WAREHOUSE',
    refresh_mode='CUSTOM_INCREMENTAL',
    incremental_strategy='append',
) }}

-- Stream-static join: each new event with its campaign's label at the time it arrives.
select e.event_id, e.campaign_id, c.label
from {{ changes(source('raw', 'events'), 'append_only') }} as e
left join {{ source('raw', 'campaigns') }} as c
  on c.campaign_id = e.campaign_id
