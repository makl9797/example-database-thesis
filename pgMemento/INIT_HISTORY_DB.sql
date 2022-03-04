SELECT pgmemento.init(
  log_old_data := TRUE,                      -- default is true
  log_new_data := TRUE,                      -- default is false
  log_state := TRUE,                         -- default is false
  trigger_create_table := TRUE               -- default is false
);