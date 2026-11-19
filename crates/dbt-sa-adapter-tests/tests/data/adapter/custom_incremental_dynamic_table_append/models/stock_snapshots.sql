{{ config(
    materialized='dynamic_table',
    snowflake_warehouse='FUSION_SLT_WAREHOUSE',
    refresh_mode='CUSTOM_INCREMENTAL',
    incremental_strategy='append',
    full_refresh=false,
) }}

-- No change source: each refresh after a source change appends the whole table again.
select sku_id, qty, current_timestamp() as snapshot_at
from {{ source('raw', 'stock') }}
