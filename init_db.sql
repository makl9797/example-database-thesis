\echo 'Install pg_memento...'
\i pgMemento/INSTALL_PGMEMENTO.sql

\echo 'Create test schemas'

CREATE SCHEMA IF NOT EXISTS with_history;
CREATE SCHEMA IF NOT EXISTS without_history;

\echo 'Initialize pg_memento...'

SELECT pgmemento.init(
  schemaname := 'with_history',                     -- default is 'public' 
  log_old_data := TRUE,                      -- default is true
  log_new_data := TRUE,                      -- default is false
  log_state := TRUE,                         -- default is false
  trigger_create_table := TRUE               -- default is false
);