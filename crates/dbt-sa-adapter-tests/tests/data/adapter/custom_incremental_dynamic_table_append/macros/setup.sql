{% macro _fq() -%}
  {{ target.database }}.{{ target.schema }}
{%- endmacro %}

{% macro set_up() %}
  {% do adapter.execute('USE DATABASE ' ~ target.database) %}
  {% do adapter.execute('CREATE OR ALTER SCHEMA ' ~ _fq()) %}
  {% for name in ['events_enriched', 'deleted_users', 'stock_snapshots', 'events_switch'] %}
    {% do adapter.execute('DROP DYNAMIC TABLE IF EXISTS ' ~ _fq() ~ '.' ~ name) %}
  {% endfor %}
  {% do adapter.execute('CREATE OR REPLACE TABLE ' ~ _fq() ~ '.events (event_id int, campaign_id int) CHANGE_TRACKING = TRUE') %}
  {% do adapter.execute('INSERT INTO ' ~ _fq() ~ '.events VALUES (1, 10), (2, 20)') %}
  {% do adapter.execute('CREATE OR REPLACE TABLE ' ~ _fq() ~ '.campaigns (campaign_id int, label varchar(16)) CHANGE_TRACKING = TRUE') %}
  {% do adapter.execute("INSERT INTO " ~ _fq() ~ ".campaigns VALUES (10, 'a'), (20, 'b')") %}
  {% do adapter.execute('CREATE OR REPLACE TABLE ' ~ _fq() ~ '.users (user_id int, user_name varchar(16)) CHANGE_TRACKING = TRUE') %}
  {% do adapter.execute("INSERT INTO " ~ _fq() ~ ".users VALUES (1, 'u1'), (2, 'u2'), (3, 'u3')") %}
  {% do adapter.execute('CREATE OR REPLACE TABLE ' ~ _fq() ~ '.stock (sku_id int, qty int) CHANGE_TRACKING = TRUE') %}
  {% do adapter.execute('INSERT INTO ' ~ _fq() ~ '.stock VALUES (1, 5), (2, 7)') %}
{% endmacro %}

{# Round 1: per source, changes an append must and must not pick up. #}
{% macro apply_changes() %}
  {% do adapter.execute('INSERT INTO ' ~ _fq() ~ '.events VALUES (3, 10)') %}
  {% do adapter.execute("UPDATE " ~ _fq() ~ ".campaigns SET label = 'a2' WHERE campaign_id = 10") %}
  {% do adapter.execute('UPDATE ' ~ _fq() ~ '.events SET campaign_id = 20 WHERE event_id = 1') %}
  {% do adapter.execute('DELETE FROM ' ~ _fq() ~ '.events WHERE event_id = 2') %}
  {% do adapter.execute('DELETE FROM ' ~ _fq() ~ '.users WHERE user_id = 1') %}
  {% do adapter.execute("UPDATE " ~ _fq() ~ ".users SET user_name = 'u2b' WHERE user_id = 2") %}
  {% do adapter.execute("INSERT INTO " ~ _fq() ~ ".users VALUES (4, 'u4')") %}
  {% do adapter.execute('DELETE FROM ' ~ _fq() ~ '.users WHERE user_id = 4') %}
  {% do adapter.execute('UPDATE ' ~ _fq() ~ '.stock SET qty = 6 WHERE sku_id = 1') %}
{% endmacro %}

{# Round 2: an event_id seen before (a merge would update it, an append adds a row), another
   delete, another stock change. #}
{% macro apply_more_changes() %}
  {% do adapter.execute('INSERT INTO ' ~ _fq() ~ '.events VALUES (4, 20), (1, 10)') %}
  {% do adapter.execute('DELETE FROM ' ~ _fq() ~ '.users WHERE user_id = 3') %}
  {% do adapter.execute('UPDATE ' ~ _fq() ~ '.stock SET qty = 8 WHERE sku_id = 2') %}
{% endmacro %}

{#- Each expectation is printed as `[PASS]`/`[FAIL]`; the stdout goldie pins the outcome. -#}
{% macro _check(label, ok) %}
  {% do log(("[PASS] " if ok else "[FAIL] ") ~ label, info=True) %}
{% endmacro %}

{% macro _scalar(sql) %}
  {% set t = run_query(sql) %}
  {% if t.rows | length == 0 %}{% do return(none) %}{% endif %}
  {% do return(t.rows[0][0]) %}
{% endmacro %}

{# Whether `actual` and `expected` (two queries) hold the same rows. #}
{% macro _same_rows(actual, expected) %}
  {% do return(_scalar(
      "select count(*) from ((" ~ actual ~ " minus " ~ expected ~ ") union all (" ~ expected ~ " minus " ~ actual ~ "))"
  ) | int == 0) %}
{% endmacro %}

{#- `stage`: after_refresh (round 1 refreshed), after_full_refresh, after_switch (round 2
    refreshed, events_switch an append through CREATE OR ALTER). -#}
{% macro verify(stage) %}
  {% set fq = _fq() %}

  {#- Old rows keep the label they were appended with; updates and deletes to events aren't read. -#}
  {% set enriched = {
      'after_refresh': "(1, 10, 'a'), (2, 20, 'b'), (3, 10, 'a2')",
      'after_full_refresh': "(1, 20, 'b'), (3, 10, 'a2')",
      'after_switch': "(1, 20, 'b'), (3, 10, 'a2'), (4, 20, 'b'), (1, 10, 'a2')",
  }[stage] %}
  {{ _check(stage ~ ": events_enriched holds each event with the label at its arrival", _same_rows(
      "select event_id, campaign_id, label from " ~ fq ~ ".events_enriched",
      "select column1, column2, column3 from values " ~ enriched)) }}

  {#- Deletes only, net per refresh (user 4 was inserted and deleted between two refreshes);
      --full-refresh keeps the log (full_refresh=false). -#}
  {% set deleted = {
      'after_refresh': "(1, 'u1')",
      'after_full_refresh': "(1, 'u1')",
      'after_switch': "(1, 'u1'), (3, 'u3')",
  }[stage] %}
  {{ _check(stage ~ ": deleted_users holds the deleted users", _same_rows(
      "select user_id, user_name from " ~ fq ~ ".deleted_users",
      "select column1, column2 from values " ~ deleted)) }}

  {#- One full copy per refresh after a change, told apart by snapshot_at. -#}
  {% set copies = {
      'after_refresh': ["(1, 5, 1), (2, 7, 2), (1, 6, 1)", 2],
      'after_full_refresh': ["(1, 5, 1), (2, 7, 2), (1, 6, 1)", 2],
      'after_switch': ["(1, 5, 1), (2, 7, 2), (1, 6, 2), (2, 8, 1)", 3],
  }[stage] %}
  {{ _check(stage ~ ": stock_snapshots holds a copy per change", _same_rows(
      "select sku_id, qty, count(*) from " ~ fq ~ ".stock_snapshots group by sku_id, qty",
      "select column1, column2, column3 from values " ~ copies[0])) }}
  {{ _check(stage ~ ": stock_snapshots copies have distinct snapshot_at", _scalar(
      "select count(distinct snapshot_at) from " ~ fq ~ ".stock_snapshots") | int == copies[1]) }}

  {#- A merge keeps one row per event_id; after the switch the same CI DT appends. -#}
  {% set switch = {
      'after_refresh': "(1, 10), (2, 20), (3, 10)",
      'after_full_refresh': "(1, 20), (3, 10)",
      'after_switch': "(1, 20), (3, 10), (4, 20), (1, 10)",
  }[stage] %}
  {{ _check(stage ~ ": events_switch holds the expected rows", _same_rows(
      "select event_id, campaign_id from " ~ fq ~ ".events_switch",
      "select column1, column2 from values " ~ switch)) }}
  {% do run_query("show dynamic tables like 'EVENTS_SWITCH' in schema " ~ fq) %}
  {{ _check(stage ~ ": events_switch is a CI DT", _scalar(
      'select "refresh_mode" from table(result_scan(last_query_id()))') == 'CUSTOM_INCREMENTAL') }}
{% endmacro %}
