-- After --full-refresh without --sample: every order.
with expected as (
    select column1 as order_id from values (1), (2), (3), (4), (5)
),

actual as (
    select order_id from {{ ref('orders_merge') }}
)

(select 'missing' as problem, * from expected minus select 'missing', * from actual)
union all
(select 'unexpected' as problem, * from actual minus select 'unexpected', * from expected)
