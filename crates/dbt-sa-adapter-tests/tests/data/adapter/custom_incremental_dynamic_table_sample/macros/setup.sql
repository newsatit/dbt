{% macro set_up() %}
  {% set orders = target.database ~ '.' ~ target.schema ~ '.orders' %}
  {% do adapter.execute('USE DATABASE ' ~ target.database) %}
  {% do adapter.execute('CREATE OR ALTER SCHEMA ' ~ target.database ~ '.' ~ target.schema) %}
  {% do adapter.execute('DROP DYNAMIC TABLE IF EXISTS ' ~ target.database ~ '.' ~ target.schema ~ '.orders_merge') %}
  {% do adapter.execute('CREATE OR REPLACE TABLE ' ~ orders ~ ' (order_id int, ordered_at timestamp_tz) CHANGE_TRACKING = TRUE') %}
  {# Order 1 is inside the 2025-01-01 to 2025-01-03 sample window, orders 2 and 3 outside it. #}
  {% do adapter.execute("INSERT INTO " ~ orders ~ " VALUES (1, '2025-01-01 12:00:00 +00:00'), (2, '2024-12-20 00:00:00 +00:00'), (3, '2025-01-05 00:00:00 +00:00')") %}
{% endmacro %}

{# Order 4 inside the window, order 5 after it. #}
{% macro apply_changes() %}
  {% set orders = target.database ~ '.' ~ target.schema ~ '.orders' %}
  {% do adapter.execute("INSERT INTO " ~ orders ~ " VALUES (4, '2025-01-02 00:00:00 +00:00'), (5, '2025-01-10 00:00:00 +00:00')") %}
{% endmacro %}
