-- After dbt run --sample (2025-01-01 to 2025-01-03): only the order in the window.
with expected as (
    select column1 as order_id from values (1)
),

actual as (
    select order_id from {{ ref('orders_merge') }}
)

(select 'missing' as problem, * from expected minus select 'missing', * from actual)
union all
(select 'unexpected' as problem, * from actual minus select 'unexpected', * from expected)
