-- After more inserts and a plain run: the CI DT still refreshes with the stored window, so order 4 (inside it) arrives and order 5 (after it) doesn't, as for a regular dynamic table.
with expected as (
    select column1 as order_id from values (1), (4)
),

actual as (
    select order_id from {{ ref('orders_merge') }}
)

(select 'missing' as problem, * from expected minus select 'missing', * from actual)
union all
(select 'unexpected' as problem, * from actual minus select 'unexpected', * from expected)
