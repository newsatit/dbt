# custom_incremental_dynamic_table_sample

A merge custom incremental dynamic table over a source with `event_time`, built with `dbt run
--sample`. `{{ changes() }}` filters the change rows by the sample window after `CHANGES`. The window
is stored in the CI DT's definition, so a later plain run (flag off: no-op, then the manual refresh)
keeps refreshing with it; `--full-refresh` without `--sample` rebuilds from every row.
