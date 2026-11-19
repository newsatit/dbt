# custom_incremental_dynamic_table_append

Append custom incremental dynamic tables (`incremental_strategy='append'`), the design doc's three
examples plus a strategy switch. Flag off; the last run turns `snowflake_dynamic_table_create_or_alter`
on. One model per scenario; the turns are shared:

| Model | Scenario |
|---|---|
| `events_enriched` | stream-static join on `append_only` changes; old rows keep the label they were appended with |
| `deleted_users` | audit log on `default` changes, deletes only, net per refresh; `full_refresh=false` keeps it across `--full-refresh` |
| `stock_snapshots` | no change source: a full copy per refresh after a change, `current_timestamp()` tells copies apart; `full_refresh=false` |
| `events_switch` | merge, then append through CREATE OR ALTER: the rows are kept (an event deleted from the source stays), a repeated `event_id` is added, not merged |

Turns (see `adapters_snowflake_custom_incremental_dynamic_table_append`): set up; create; round 1;
a run; `verify`; `--full-refresh`; `verify`; round 2; a run with `switched.yml`; `verify`.
`verify` prints `[PASS]`/`[FAIL]` per expectation.
