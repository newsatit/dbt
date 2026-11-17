{%- if var('switch_to_append') -%}
{{ config(
    materialized='dynamic_table',
    snowflake_warehouse='FUSION_SLT_WAREHOUSE',
    refresh_mode='CUSTOM_INCREMENTAL',
    incremental_strategy='append',
    unique_key='event_id',
) }}
-- An append now; unique_key stays set and is ignored.
{%- else -%}
{{ config(
    materialized='dynamic_table',
    snowflake_warehouse='FUSION_SLT_WAREHOUSE',
    refresh_mode='CUSTOM_INCREMENTAL',
    incremental_strategy='merge',
    unique_key='event_id',
) }}
{%- endif %}
select e.event_id, e.campaign_id
from {{ changes(source('raw', 'events'), 'append_only') }} as e
