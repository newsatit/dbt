{{ config(
    materialized='dynamic_table',
    snowflake_warehouse='FUSION_SLT_WAREHOUSE',
    refresh_mode='CUSTOM_INCREMENTAL',
    incremental_strategy='append',
    full_refresh=false,
) }}

-- Audit log: users deleted from the source, kept across --full-refresh.
select user_id, user_name
from {{ changes(source('raw', 'users'), 'default') }}
where metadata$action = 'DELETE'
  and not metadata$isupdate
