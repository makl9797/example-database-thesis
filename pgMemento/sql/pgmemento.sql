-- SCHEMA.sql
--
-- Author:      Felix Kunde <felix-kunde@gmx.de>
--
--              This script is free software under the LGPL Version 3
--              See the GNU Lesser General Public License at
--              http://www.gnu.org/copyleft/lgpl.html
--              for more details.
-------------------------------------------------------------------------------
-- About:
-- This script contains the database schema of pgMemento.
--
-------------------------------------------------------------------------------
--
-- ChangeLog:
--
-- Version | Date       | Description                                        | Author
-- 0.7.4     2020-03-23   add audit_id_column to audit_table_log               FKun
-- 0.7.3     2020-03-21   new audit_schema_log table                           FKun
-- 0.7.2     2020-02-29   new column in row_log to also audit new data         FKun
--                        new unique index on event_key and audit_id
-- 0.7.1     2020-02-02   put unique index of table_event_log on event_key     FKun
-- 0.7.0     2020-01-09   remove FK to events and use concatenated metakeys    FKun
--                        store more events with statement_timestamp
-- 0.6.2     2019-02-27   comments for tables and columns                      FKun
-- 0.6.1     2018-07-23   schema part cut from SETUP.sql                       FKun
--

/**********************************************************
* C-o-n-t-e-n-t:
*
* PGMEMENTO SCHEMA
*   Addtional schema that contains the log tables and
*   all functions to enable versioning of the database.
*
* TABLES:
*   audit_column_log
*   audit_table_log
*   audit_schema_log
*   row_log
*   table_event_log
*   transaction_log
*
* INDEXES:
*   column_log_column_idx
*   column_log_range_idx
*   column_log_table_idx
*   row_log_audit_idx
*   row_log_event_idx
*   row_log_new_data_idx
*   row_log_old_data_idx
*   table_event_log_event_idx
*   table_event_log_fk_idx
*   table_log_idx
*   table_log_range_idx
*   transaction_log_session_idx
*   transaction_log_txid_idx
*
* SEQUENCES:
*   audit_id_seq
*   schema_log_id_seq
*   table_log_id_seq
*
***********************************************************/

-- transaction metadata is logged into the transaction_log table
DROP TABLE IF EXISTS pgmemento.transaction_log CASCADE;
CREATE TABLE pgmemento.transaction_log
(
  id SERIAL,
  txid BIGINT NOT NULL,
  txid_time TIMESTAMP WITH TIME ZONE NOT NULL,
  process_id INTEGER,
  user_name TEXT,
  client_name TEXT,
  client_port INTEGER,
  application_name TEXT,
  session_info JSONB
);

ALTER TABLE pgmemento.transaction_log
  ADD CONSTRAINT transaction_log_pk PRIMARY KEY (id);

COMMENT ON TABLE pgmemento.transaction_log IS 'Stores metadata about each transaction';
COMMENT ON COLUMN pgmemento.transaction_log.id IS 'The Primary Key';
COMMENT ON COLUMN pgmemento.transaction_log.txid IS 'The internal transaction ID by PostgreSQL (can cycle)';
COMMENT ON COLUMN pgmemento.transaction_log.txid_time IS 'Stores the result of transaction_timestamp() function';
COMMENT ON COLUMN pgmemento.transaction_log.process_id IS 'Stores the result of pg_backend_pid() function';
COMMENT ON COLUMN pgmemento.transaction_log.user_name IS 'Stores the result of session_user function';
COMMENT ON COLUMN pgmemento.transaction_log.client_name IS 'Stores the result of inet_client_addr() function';
COMMENT ON COLUMN pgmemento.transaction_log.client_port IS 'Stores the result of inet_client_port() function';
COMMENT ON COLUMN pgmemento.transaction_log.application_name IS 'Stores the output of current_setting(''application_name'')';
COMMENT ON COLUMN pgmemento.transaction_log.session_info IS 'Stores any infos a client/user defines beforehand with set_config';

-- event on tables are logged into the table_event_log table
DROP TABLE IF EXISTS pgmemento.table_event_log CASCADE;
CREATE TABLE pgmemento.table_event_log
(
  id SERIAL,
  transaction_id INTEGER NOT NULL,
  stmt_time TIMESTAMP WITH TIME ZONE NOT NULL,
  op_id SMALLINT NOT NULL,
  table_operation TEXT,
  table_name TEXT NOT NULL,
  schema_name TEXT NOT NULL,
  event_key TEXT NOT NULL
);

ALTER TABLE pgmemento.table_event_log
  ADD CONSTRAINT table_event_log_pk PRIMARY KEY (id);

COMMENT ON TABLE pgmemento.table_event_log IS 'Stores metadata about different kind of events happening during one transaction against one table';
COMMENT ON COLUMN pgmemento.table_event_log.id IS 'The Primary Key';
COMMENT ON COLUMN pgmemento.table_event_log.transaction_id IS 'Foreign Key to transaction_log table';
COMMENT ON COLUMN pgmemento.table_event_log.stmt_time IS 'Stores the result of statement_timestamp() function';
COMMENT ON COLUMN pgmemento.table_event_log.op_id IS 'ID of event type';
COMMENT ON COLUMN pgmemento.table_event_log.table_operation IS 'Text for of event type';
COMMENT ON COLUMN pgmemento.table_event_log.table_name IS 'Name of table that fired the trigger';
COMMENT ON COLUMN pgmemento.table_event_log.schema_name IS 'Schema of firing table';
COMMENT ON COLUMN pgmemento.table_event_log.event_key IS 'Concatenated information of most columns';

-- all row changes are logged into the row_log table
DROP TABLE IF EXISTS pgmemento.row_log CASCADE;
CREATE TABLE pgmemento.row_log
(
  id BIGSERIAL,
  audit_id BIGINT NOT NULL,
  event_key TEXT NOT NULL,
  old_data JSONB,
  new_data JSONB
);

ALTER TABLE pgmemento.row_log
  ADD CONSTRAINT row_log_pk PRIMARY KEY (id);

COMMENT ON TABLE pgmemento.row_log IS 'Stores the historic data a.k.a the audit trail';
COMMENT ON COLUMN pgmemento.row_log.id IS 'The Primary Key';
COMMENT ON COLUMN pgmemento.row_log.audit_id IS ' The implicit link to a table''s row';
COMMENT ON COLUMN pgmemento.row_log.event_key IS 'Concatenated information of table event';
COMMENT ON COLUMN pgmemento.row_log.old_data IS 'The old values of changed columns in a JSONB object';
COMMENT ON COLUMN pgmemento.row_log.new_data IS 'The new values of changed columns in a JSONB object';

-- if and how pgMemento is running, is logged in the audit_schema_log
CREATE TABLE pgmemento.audit_schema_log (
  id SERIAL,
  log_id INTEGER NOT NULL,
  schema_name TEXT NOT NULL,
  default_audit_id_column TEXT NOT NULL,
  default_log_old_data BOOLEAN DEFAULT TRUE,
  default_log_new_data BOOLEAN DEFAULT FALSE,
  trigger_create_table BOOLEAN DEFAULT FALSE,
  txid_range numrange
);

ALTER TABLE pgmemento.audit_schema_log
  ADD CONSTRAINT audit_schema_log_pk PRIMARY KEY (id);

COMMENT ON TABLE pgmemento.audit_schema_log IS 'Stores information about how pgMemento is configured in audited database schema';
COMMENT ON COLUMN pgmemento.audit_schema_log.id IS 'The Primary Key';
COMMENT ON COLUMN pgmemento.audit_schema_log.log_id IS 'ID to trace a changing database schema';
COMMENT ON COLUMN pgmemento.audit_schema_log.schema_name IS 'The name of the database schema';
COMMENT ON COLUMN pgmemento.audit_schema_log.default_audit_id_column IS 'The default name for the audit_id column added to audited tables';
COMMENT ON COLUMN pgmemento.audit_schema_log.default_log_old_data IS 'Default setting for tables to log old values';
COMMENT ON COLUMN pgmemento.audit_schema_log.default_log_new_data IS 'Default setting for tables to log new values';
COMMENT ON COLUMN pgmemento.audit_schema_log.trigger_create_table IS 'Flag that shows if pgMemento starts auditing for newly created tables';
COMMENT ON COLUMN pgmemento.audit_schema_log.txid_range IS 'Stores the transaction IDs when pgMemento has been activated or stopped in the schema';

-- liftime of audited tables is logged in the audit_table_log table
CREATE TABLE pgmemento.audit_table_log (
  id SERIAL,
  log_id INTEGER NOT NULL,
  relid OID,
  table_name TEXT NOT NULL,
  schema_name TEXT NOT NULL,
  audit_id_column TEXT NOT NULL,
  log_old_data BOOLEAN NOT NULL,
  log_new_data BOOLEAN NOT NULL,
  txid_range numrange
);

ALTER TABLE pgmemento.audit_table_log
  ADD CONSTRAINT audit_table_log_pk PRIMARY KEY (id);

COMMENT ON TABLE pgmemento.audit_table_log IS 'Stores information about audited tables, which is important when restoring a whole schema or database';
COMMENT ON COLUMN pgmemento.audit_table_log.id IS 'The Primary Key';
COMMENT ON COLUMN pgmemento.audit_table_log.log_id IS 'ID to trace a changing table';
COMMENT ON COLUMN pgmemento.audit_table_log.relid IS '[DEPRECATED] The table''s OID to trace a table when changed';
COMMENT ON COLUMN pgmemento.audit_table_log.table_name IS 'The name of the table';
COMMENT ON COLUMN pgmemento.audit_table_log.schema_name IS 'The schema the table belongs to';
COMMENT ON COLUMN pgmemento.audit_table_log.audit_id_column IS 'The name for the audit_id column added to the audited table';
COMMENT ON COLUMN pgmemento.audit_table_log.log_old_data IS 'Flag that shows if old values are logged for audited table';
COMMENT ON COLUMN pgmemento.audit_table_log.log_new_data IS 'Flag that shows if new values are logged for audited table';
COMMENT ON COLUMN pgmemento.audit_table_log.txid_range IS 'Stores the transaction IDs when the table has been created and dropped';

-- lifetime of columns of audited tables is logged in the audit_column_log table
CREATE TABLE pgmemento.audit_column_log (
  id SERIAL,
  audit_table_id INTEGER NOT NULL,
  column_name TEXT NOT NULL,
  ordinal_position INTEGER,
  data_type TEXT,
  column_default TEXT,
  not_null BOOLEAN,
  txid_range numrange
);

ALTER TABLE pgmemento.audit_column_log
  ADD CONSTRAINT audit_column_log_pk PRIMARY KEY (id);

COMMENT ON TABLE pgmemento.audit_column_log IS 'Stores information about audited columns, which is important when restoring previous versions of tuples and tables';
COMMENT ON COLUMN pgmemento.audit_column_log.id IS 'The Primary Key';
COMMENT ON COLUMN pgmemento.audit_column_log.audit_table_id IS 'Foreign Key to pgmemento.audit_table_log';
COMMENT ON COLUMN pgmemento.audit_column_log.column_name IS 'The name of the column';
COMMENT ON COLUMN pgmemento.audit_column_log.ordinal_position IS 'The ordinal position within the table';
COMMENT ON COLUMN pgmemento.audit_column_log.data_type IS 'The column''s data type (incl typemods)';
COMMENT ON COLUMN pgmemento.audit_column_log.column_default IS 'The column''s default expression';
COMMENT ON COLUMN pgmemento.audit_column_log.not_null IS 'A flag to tell, if the column is a NOT NULL column or not';
COMMENT ON COLUMN pgmemento.audit_column_log.txid_range IS 'Stores the transaction IDs when the column has been created and dropped';

-- create foreign key constraints
ALTER TABLE pgmemento.table_event_log
  ADD CONSTRAINT table_event_log_txid_fk
    FOREIGN KEY (transaction_id)
    REFERENCES pgmemento.transaction_log (id)
    MATCH FULL
    ON DELETE CASCADE
    ON UPDATE CASCADE;

ALTER TABLE pgmemento.audit_column_log
  ADD CONSTRAINT audit_column_log_fk
    FOREIGN KEY (audit_table_id)
    REFERENCES pgmemento.audit_table_log (id)
    MATCH FULL
    ON DELETE CASCADE
    ON UPDATE CASCADE;

-- create indexes on all columns that are queried later
DROP INDEX IF EXISTS transaction_log_unique_idx;
DROP INDEX IF EXISTS transaction_log_session_idx;
DROP INDEX IF EXISTS table_event_log_fk_idx;
DROP INDEX IF EXISTS table_event_log_event_idx;
DROP INDEX IF EXISTS row_log_audit_idx;
DROP INDEX IF EXISTS row_log_event_audit_idx;
DROP INDEX IF EXISTS row_log_old_data_idx;
DROP INDEX IF EXISTS row_log_new_data_idx;
DROP INDEX IF EXISTS table_log_idx;
DROP INDEX IF EXISTS table_log_range_idx;
DROP INDEX IF EXISTS column_log_table_idx;
DROP INDEX IF EXISTS column_log_column_idx;
DROP INDEX IF EXISTS column_log_range_idx;

CREATE UNIQUE INDEX transaction_log_unique_idx ON pgmemento.transaction_log USING BTREE (txid_time, txid);
CREATE INDEX transaction_log_session_idx ON pgmemento.transaction_log USING GIN (session_info);
CREATE INDEX table_event_log_fk_idx ON pgmemento.table_event_log USING BTREE (transaction_id);
CREATE UNIQUE INDEX table_event_log_event_idx ON pgmemento.table_event_log USING BTREE (event_key);
CREATE INDEX row_log_audit_idx ON pgmemento.row_log USING BTREE (audit_id);
CREATE UNIQUE INDEX row_log_event_audit_idx ON pgmemento.row_log USING BTREE (event_key, audit_id);
CREATE INDEX row_log_old_data_idx ON pgmemento.row_log USING GIN (old_data);
CREATE INDEX row_log_new_data_idx ON pgmemento.row_log USING GIN (new_data);
CREATE INDEX table_log_idx ON pgmemento.audit_table_log USING BTREE (log_id);
CREATE INDEX table_log_name_idx ON pgmemento.audit_table_log USING BTREE (table_name, schema_name);
CREATE INDEX table_log_range_idx ON pgmemento.audit_table_log USING GIST (txid_range);
CREATE INDEX column_log_table_idx ON pgmemento.audit_column_log USING BTREE (audit_table_id);
CREATE INDEX column_log_column_idx ON pgmemento.audit_column_log USING BTREE (column_name);
CREATE INDEX column_log_range_idx ON pgmemento.audit_column_log USING GIST (txid_range);


/***********************************************************
CREATE SEQUENCE

***********************************************************/
DROP SEQUENCE IF EXISTS pgmemento.audit_id_seq;
CREATE SEQUENCE pgmemento.audit_id_seq
  INCREMENT BY 1
  MINVALUE 0
  MAXVALUE 2147483647
  START WITH 1
  CACHE 1
  NO CYCLE
  OWNED BY NONE;

DROP SEQUENCE IF EXISTS pgmemento.schema_log_id_seq;
CREATE SEQUENCE pgmemento.schema_log_id_seq
  INCREMENT BY 1
  MINVALUE 0
  MAXVALUE 2147483647
  START WITH 1
  CACHE 1
  NO CYCLE
  OWNED BY NONE;

DROP SEQUENCE IF EXISTS pgmemento.table_log_id_seq;
CREATE SEQUENCE pgmemento.table_log_id_seq
  INCREMENT BY 1
  MINVALUE 0
  MAXVALUE 2147483647
  START WITH 1
  CACHE 1
  NO CYCLE
  OWNED BY NONE;
-- SETUP.sql
--
-- Author:      Felix Kunde <felix-kunde@gmx.de>
--
--              This script is free software under the LGPL Version 3
--              See the GNU Lesser General Public License at
--              http://www.gnu.org/copyleft/lgpl.html
--              for more details.
-------------------------------------------------------------------------------
-- About:
-- This script provides functions to set up pgMemento for a schema in an
-- PostgreSQL 9.5+ database.
-------------------------------------------------------------------------------
--
-- ChangeLog:
--
-- Version | Date       | Description                                       | Author
-- 0.7.13    2021-12-23   concat jsonb logs on upsert                         FKun
-- 0.7.12    2021-12-23   session variables must start with letter in Pg14    ol-teuto
-- 0.7.11    2021-03-28   exclude audit_tables with empty txid_range          FKun
-- 0.7.10    2020-04-19   change signature for drop audit functions and       FKun
--                        define new REINIT TABLE event
-- 0.7.9     2020-04-13   remove txid from log_table_event                    FKun
-- 0.7.8     2020-03-29   make logging of old data configurable, too          FKun
-- 0.7.7     2020-03-23   allow configurable audit_id column                  FKun
-- 0.7.6     2020-03-21   new function log_transaction to do writes and       FKun
--                        renamed trigger function to log_statement
-- 0.7.5     2020-03-07   set SECURITY DEFINER where log tables are touched   FKun
-- 0.7.4     2020-02-29   added option to also log new data in row_log        FKun
-- 0.7.3     2020-02-09   reflect changes on schema and triggers              FKun
-- 0.7.2     2020-02-08   new get_table_oid function to replace trimming      FKun
-- 0.7.1     2019-04-21   introduce new event RECREATE TABLE with op_id       FKun
-- 0.7.0     2019-03-23   reflect schema changes in UDFs and VIEWs            FKun
-- 0.6.9     2019-03-23   Audit views list tables even on relid mismatch      FKun
-- 0.6.8     2019-02-14   ADD AUDIT_ID event gets its own op_id               FKun
--                        new helper function trim_outer_quotes
-- 0.6.7     2018-11-19   new log events for adding and dropping audit_id     FKun
-- 0.6.6     2018-11-10   rename log_table_state to log_table_baseline        FKun
--                        new option for drop_table_audit to drop all logs
-- 0.6.5     2018-11-05   get_txid_bounds_to_table function now takes OID     FKun
-- 0.6.4     2018-11-01   reflect range bounds change in audit tables         FKun
-- 0.6.3     2018-10-26   fixed delta creation for UPDATEs with JSON types    FKun
-- 0.6.2     2018-10-25   log_state argument changed to boolean               FKun
-- 0.6.1     2018-07-23   moved schema parts in its own file                  FKun
-- 0.6.0     2018-07-14   additional columns in transaction_log table and     FKun
--                        better handling for internal txid cycles
-- 0.5.3     2017-07-26   Improved queries for views                          FKun
-- 0.5.2     2017-07-25   UNIQUE constraint for audit_id column, new op_ids   FKun
--                        new column order in audit_column_log
-- 0.5.1     2017-07-18   add functions un/register_audit_table               FKun
-- 0.5.0     2017-07-12   simplified schema for audit_column_log              FKun
-- 0.4.2     2017-04-10   included parts from other scripts                   FKun
-- 0.4.1     2017-03-15   empty JSONB diffs are not logged anymore            FKun
--                        updated schema for DDL log tables
-- 0.4.0     2017-03-05   updated JSONB functions                             FKun
-- 0.3.0     2016-04-14   new log tables for ddl changes (removed             FKun
--                        table_templates table)
-- 0.2.4     2016-04-05   more constraints on log tables (+ new ID column)    FKun
-- 0.2.3     2016-03-17   work with time zones and renamed column in          FKun
--                        table_templates table
-- 0.2.2     2016-03-09   fallbacks for adding columns and triggers           FKun
-- 0.2.1     2016-02-14   removed unnecessary plpgsql and dynamic sql code    FKun
-- 0.2.0     2015-02-21   new table structure, more triggers and JSONB        FKun
-- 0.1.0     2014-11-26   initial commit                                      FKun
--

/**********************************************************
* C-o-n-t-e-n-t:
*
* VIEWS:
*   audit_tables
*   audit_tables_dependency
*
* FUNCTIONS:
*   column_array_to_column_list(columns TEXT[]) RETURNS TEXT
*   create_schema_audit(schemaname TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
*     log_state BOOLEAN DEFAULT FALSE, log_new_data BOOLEAN DEFAULT FALSE, trigger_create_table BOOLEAN DEFAULT FALSE,
*     except_tables TEXT[] DEFAULT '{}') RETURNS SETOF VOID
*   create_schema_audit_id(schemaname TEXT DEFAULT 'public'::text, except_tables TEXT[] DEFAULT '{}') RETURNS SETOF VOID
*   create_schema_log_trigger(schemaname TEXT DEFAULT 'public'::text, log_old_data BOOLEAN DEFAULT TRUE,
*     log_new_data BOOLEAN DEFAULT FALSE, except_tables TEXT[] DEFAULT '{}') RETURNS SETOF VOID
*   create_table_audit(tablename TEXT, schemaname TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
*     log_old_data BOOLEAN DEFAULT TRUE, log_new_data BOOLEAN DEFAULT FALSE ,log_state BOOLEAN DEFAULT FALSE) RETURNS SETOF VOID
*   create_table_audit_id(table_name TEXT, schema_name TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text) RETURNS SETOF VOID
*   create_table_log_trigger(table_name TEXT, schema_name TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
*     log_old_data BOOLEAN DEFAULT TRUE, log_new_data BOOLEAN DEFAULT FALSE, log_state BOOLEAN DEFAULT FALSE) RETURNS SETOF VOID
*   drop_schema_audit(schema_name TEXT DEFAULT 'public'::text, log_state BOOLEAN DEFAULT TRUE, drop_log BOOLEAN DEFAULT FALSE, except_tables TEXT[] DEFAULT '{}') RETURNS SETOF VOID
*   drop_schema_audit_id(schema_name TEXT DEFAULT 'public'::text, except_tables TEXT[] DEFAULT '{}') RETURNS SETOF VOID
*   drop_schema_log_trigger(schema_name TEXT DEFAULT 'public'::text, except_tables TEXT[] DEFAULT '{}') RETURNS SETOF VOID
*   drop_table_audit(table_name TEXT, schema_name TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
*     log_state BOOLEAN DEFAULT TRUE, drop_log BOOLEAN DEFAULT FALSE) RETURNS SETOF VOID
*   drop_table_audit_id(table_name TEXT, schema_name TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text) RETURNS SETOF VOID
*   drop_table_log_trigger(table_name TEXT, schema_name TEXT DEFAULT 'public'::text) RETURNS SETOF VOID
*   get_operation_id(operation TEXT) RETURNS SMALLINT
*   get_table_oid(table_name TEXT, schema_name TEXT DEFAULT 'public'::text) RETURNS OID
*   get_txid_bounds_to_table(table_log_id INTEGER, OUT txid_min INTEGER, OUT txid_max INTEGER) RETURNS RECORD
*   log_new_table_state(columns TEXT[], table_name TEXT, schema_name TEXT DEFAULT 'public'::text, table_event_key TEXT,
*     audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text) RETURNS SETOF VOID
*   log_old_table_state(columns TEXT[], table_name TEXT, schema_name TEXT DEFAULT 'public'::text, table_event_key TEXT,
      audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text) RETURNS SETOF VOID
*   log_schema_baseline(audit_schema_name TEXT DEFAULT 'public'::text) RETURNS SETOF VOID
*   log_table_baseline(table_name TEXT, schema_name TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
*     log_new_data BOOLEAN DEFAULT FALSE) RETURNS SETOF VOID
*   log_table_event(event_txid BIGINT, tablename TEXT, schemaname TEXT, op_type TEXT) RETURNS TEXT
*   log_transaction(current_txid BIGINT) RETURNS INTEGER
*   register_audit_table(audit_table_name TEXT, audit_schema_name TEXT DEFAULT 'public'::text) RETURNS INTEGER
*   trim_outer_quotes(quoted_string TEXT) RETURNS TEXT
*   unregister_audit_table(audit_table_name TEXT, audit_schema_name TEXT DEFAULT 'public'::text) RETURNS SETOF VOID
*
* TRIGGER FUNCTIONS
*   log_delete() RETURNS trigger
*   log_insert() RETURNS trigger
*   log_tansaction() RETURNS trigger
*   log_truncate() RETURNS trigger
*   log_update() RETURNS trigger
*
***********************************************************/

/***********************************************************
* GET TXID BOUNDS TO TABLE
*
* A helper function to get highest and lowest logged
* transaction id to an audited table
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.get_txid_bounds_to_table(
  table_log_id INTEGER,
  OUT txid_min INTEGER,
  OUT txid_max INTEGER
  ) RETURNS RECORD AS
$$
SELECT
  min(transaction_id) AS txid_min,
  max(transaction_id) AS txid_max
FROM
  pgmemento.table_event_log
WHERE
  table_log_id = $1;
$$
LANGUAGE sql STABLE STRICT;


/***********************************************************
* AUDIT_TABLES VIEW
*
* A view that shows the user at which transaction auditing
* has been started.
***********************************************************/
CREATE OR REPLACE VIEW pgmemento.audit_tables AS
  SELECT
    n.nspname AS schemaname,
    c.relname AS tablename,
    atl.audit_id_column,
    atl.log_old_data,
    atl.log_new_data,
    bounds.txid_min,
    bounds.txid_max,
    CASE WHEN tg.tgenabled IS NOT NULL AND tg.tgenabled <> 'D' THEN
      TRUE
    ELSE
      FALSE
    END AS tg_is_active
  FROM
    pg_class c
  JOIN
    pg_namespace n
    ON c.relnamespace = n.oid
  JOIN
    pgmemento.audit_schema_log asl
    ON asl.schema_name = n.nspname
   AND upper(asl.txid_range) IS NULL
   AND lower(asl.txid_range) IS NOT NULL
  JOIN (
    SELECT DISTINCT ON (log_id)
      log_id,
      table_name,
      schema_name,
      audit_id_column,
      log_old_data,
      log_new_data
    FROM
      pgmemento.audit_table_log
    WHERE
      upper(txid_range) IS NULL
      AND lower(txid_range) IS NOT NULL
    ORDER BY
      log_id, id
    ) atl
    ON atl.table_name = c.relname
   AND atl.schema_name = n.nspname
  JOIN
    pg_attribute a
    ON a.attrelid = c.oid
   AND a.attname = atl.audit_id_column
  JOIN LATERAL (
    SELECT * FROM pgmemento.get_txid_bounds_to_table(atl.log_id)
    ) bounds ON (true)
  LEFT JOIN (
    SELECT
      tgrelid,
      tgenabled
    FROM
      pg_trigger
    WHERE
      tgname = 'pgmemento_transaction_trigger'::name
    ) AS tg
    ON c.oid = tg.tgrelid
  WHERE
    c.relkind = 'r'
  ORDER BY
    schemaname,
    tablename;

COMMENT ON VIEW pgmemento.audit_tables IS 'Lists which tables are audited by pgMemento (a.k.a. have an audit_id column)';
COMMENT ON COLUMN pgmemento.audit_tables.schemaname IS 'The schema the audited table belongs to';
COMMENT ON COLUMN pgmemento.audit_tables.tablename IS 'Name of the audited table';
COMMENT ON COLUMN pgmemento.audit_tables.audit_id_column IS 'Name of the audit_id column added to the audited table';
COMMENT ON COLUMN pgmemento.audit_tables.log_old_data IS 'Flag that shows if old values are logged for audited table';
COMMENT ON COLUMN pgmemento.audit_tables.log_new_data IS 'Flag that shows if new values are logged for audited table';
COMMENT ON COLUMN pgmemento.audit_tables.txid_min IS 'The minimal transaction ID referenced to the audited table in the table_event_log';
COMMENT ON COLUMN pgmemento.audit_tables.txid_max IS 'The maximal transaction ID referenced to the audited table in the table_event_log';
COMMENT ON COLUMN pgmemento.audit_tables.tg_is_active IS 'Flag, that shows if logging is activated for the table or not';

/***********************************************************
* AUDIT_TABLES_DEPENDENCY VIEW
*
* This view is essential for reverting transactions.
* pgMemento can only log one INSERT/UPDATE/DELETE event per
* table per transaction which maps all changed rows to this
* one event even though it belongs to a subsequent one.
* Therefore, knowledge about table dependencies is required
* to not violate foreign keys.
***********************************************************/
CREATE OR REPLACE VIEW pgmemento.audit_tables_dependency AS
  WITH RECURSIVE table_dependency(
    parent_oid,
    child_oid,
    table_log_id,
    table_name,
    schema_name,
    depth
  ) AS (
    SELECT DISTINCT ON (ct.conrelid)
      ct.confrelid AS parent_oid,
      ct.conrelid AS child_oid,
      a.log_id AS table_log_id,
      a.table_name,
      n.nspname AS schema_name,
      1 AS depth
    FROM
      pg_class c
    JOIN
      pg_namespace n
      ON n.oid = c.relnamespace
    JOIN
      pg_constraint ct
      ON ct.conrelid = c.oid
    JOIN pgmemento.audit_table_log a
      ON a.table_name = c.relname
     AND a.schema_name = n.nspname
     AND upper(a.txid_range) IS NULL
     AND lower(a.txid_range) IS NOT NULL
    WHERE
      ct.contype = 'f'
      AND ct.conrelid <> ct.confrelid
    UNION ALL
      SELECT DISTINCT ON (ct.conrelid)
        ct.confrelid AS parent_oid,
        ct.conrelid AS child_oid,
        a.log_id AS table_log_id,
        a.table_name,
        n.nspname AS schema_name,
        d.depth + 1 AS depth
      FROM
        pg_class c
      JOIN
        pg_namespace n
        ON n.oid = c.relnamespace
      JOIN
        pg_constraint ct
        ON ct.conrelid = c.oid
      JOIN pgmemento.audit_table_log a
        ON a.table_name = c.relname
       AND a.schema_name = n.nspname
       AND upper(a.txid_range) IS NULL
       AND lower(a.txid_range) IS NOT NULL
      JOIN table_dependency d
        ON d.child_oid = ct.confrelid
      WHERE
        ct.contype = 'f'
        AND d.child_oid <> ct.conrelid
  )
  SELECT
    child_oid AS relid,
    table_log_id,
    schema_name AS schemaname,
    table_name AS tablename,
    depth
  FROM (
    SELECT
      child_oid,
      table_log_id,
      schema_name,
      table_name,
      max(depth) AS depth
    FROM
      table_dependency
    GROUP BY
      child_oid,
      table_log_id,
      schema_name,
      table_name
    UNION ALL
      SELECT
        atl.relid,
        atl.log_id AS table_log_id,
        atl.schema_name,
        atl.table_name,
        0 AS depth
      FROM
        pgmemento.audit_table_log atl
      LEFT JOIN
        table_dependency d
        ON d.table_log_id = atl.log_id
      WHERE
        d.table_log_id IS NULL
        AND upper(atl.txid_range) IS NULL
        AND lower(atl.txid_range) IS NOT NULL
  ) td
  ORDER BY
    schemaname,
    depth,
    tablename;

COMMENT ON VIEW pgmemento.audit_tables_dependency IS 'Lists the dependencies between audited tables which is important for reverts';
COMMENT ON COLUMN pgmemento.audit_tables_dependency.relid IS 'The OID of the table';
COMMENT ON COLUMN pgmemento.audit_tables_dependency.table_log_id IS 'The tracing log ID from audit_table_log';
COMMENT ON COLUMN pgmemento.audit_tables_dependency.schemaname IS 'The schema name the table belongs to';
COMMENT ON COLUMN pgmemento.audit_tables_dependency.tablename IS 'The name of the table';
COMMENT ON COLUMN pgmemento.audit_tables_dependency.depth IS 'The depth of foreign key references';


/**********************************************************
* TRIM_OUTER_QUOTES
*
* Helper function to support auditing quoted tables
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.trim_outer_quotes(quoted_string TEXT) RETURNS TEXT AS
$$
SELECT
  CASE WHEN length(btrim($1, '"')) < length($1)
  THEN replace(substr($1, 2, length($1) - 2),'""','"')
  ELSE replace($1,'""','"')
  END;
$$
LANGUAGE sql;

/**********************************************************
* GET_OPERATION_iD
*
* Helper function to return id for triggered operation
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.get_operation_id(operation TEXT) RETURNS SMALLINT AS
$$
SELECT (CASE $1
  WHEN 'CREATE TABLE' THEN 1
  WHEN 'RECREATE TABLE' THEN 1
  WHEN 'REINIT TABLE' THEN 11
  WHEN 'RENAME TABLE' THEN 12
  WHEN 'ADD COLUMN' THEN 2
  WHEN 'ADD AUDIT_ID' THEN 21
  WHEN 'RENAME COLUMN' THEN 22
  WHEN 'INSERT' THEN 3
  WHEN 'UPDATE' THEN 4
  WHEN 'ALTER COLUMN' THEN 5
  WHEN 'DROP COLUMN' THEN 6
  WHEN 'DELETE' THEN 7
  WHEN 'TRUNCATE' THEN 8
  WHEN 'DROP AUDIT_ID' THEN 81
  WHEN 'DROP TABLE' THEN 9
  ELSE NULL
END)::smallint;
$$
LANGUAGE sql IMMUTABLE STRICT;

/**********************************************************
* GET_TABLE_OID
*
* Returns the OID for schema.table / "schema"."table"
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.get_table_oid(
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text
  ) RETURNS OID AS
$$
DECLARE
  table_oid OID;
BEGIN
  table_oid := ($2 || '.' || $1)::regclass::oid;
  RETURN table_oid;

  EXCEPTION
    WHEN others THEN
      table_oid := (quote_ident($2) || '.' || quote_ident($1))::regclass::oid;
      RETURN table_oid;
END;
$$
LANGUAGE plpgsql STRICT;


/**********************************************************
* UN/REGISTER TABLE
*
* Function to un/register information of audited table in
* audit_table_log and corresponding columns in audit_column_log
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.unregister_audit_table(
  audit_table_name TEXT,
  audit_schema_name TEXT DEFAULT 'public'::text
  ) RETURNS SETOF VOID AS
$$
DECLARE
  tab_id INTEGER;
BEGIN
  -- update txid_range for removed table in audit_table_log table
  UPDATE
    pgmemento.audit_table_log
  SET
    txid_range = numrange(lower(txid_range), current_setting('pgmemento.t' || txid_current())::numeric, '(]')
  WHERE
    table_name = $1
    AND schema_name = $2
    AND upper(txid_range) IS NULL
    AND lower(txid_range) IS NOT NULL
  RETURNING
    id INTO tab_id;

  IF tab_id IS NOT NULL THEN
    -- update txid_range for removed columns in audit_column_log table
    UPDATE
      pgmemento.audit_column_log
    SET
      txid_range = numrange(lower(txid_range), current_setting('pgmemento.t' || txid_current())::numeric, '(]')
    WHERE
      audit_table_id = tab_id
      AND upper(txid_range) IS NULL
      AND lower(txid_range) IS NOT NULL;
  END IF;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

CREATE OR REPLACE FUNCTION pgmemento.register_audit_table(
  audit_table_name TEXT,
  audit_schema_name TEXT DEFAULT 'public'::text
  ) RETURNS INTEGER AS
$$
DECLARE
  tab_id INTEGER;
  table_log_id INTEGER;
  old_table_name TEXT;
  old_schema_name TEXT;
  audit_id_column_name TEXT;
  log_data_settings TEXT;
BEGIN
  -- check if affected table exists in 'audit_table_log' (with open range)
  SELECT
    id INTO tab_id
  FROM
    pgmemento.audit_table_log
  WHERE
    table_name = $1
    AND schema_name = $2
    AND upper(txid_range) IS NULL
    AND lower(txid_range) IS NOT NULL;

  IF tab_id IS NOT NULL THEN
    RETURN tab_id;
  END IF;

  BEGIN
    -- check if table exists in 'audit_table_log' with another name (and open range)
    table_log_id := current_setting('pgmemento.' || quote_ident($2) || '.' || quote_ident($1))::int;

    IF NOT EXISTS (
      SELECT
        1
      FROM
        pgmemento.table_event_log
      WHERE
        transaction_id = current_setting('pgmemento.t' || txid_current())::int
        AND table_name = $1
        AND schema_name = $2
        AND ((op_id = 1 AND table_operation = 'RECREATE TABLE')
         OR op_id = 11)  -- REINIT TABLE event
    ) THEN
      SELECT
        table_name,
        schema_name
      INTO
        old_table_name,
        old_schema_name
      FROM
        pgmemento.audit_table_log
      WHERE
        log_id = table_log_id
        AND upper(txid_range) IS NULL
        AND lower(txid_range) IS NOT NULL;
    END IF;

    EXCEPTION
      WHEN others THEN
        table_log_id := nextval('pgmemento.table_log_id_seq');
  END;

  -- if so, unregister first before making new inserts
  IF old_table_name IS NOT NULL AND old_schema_name IS NOT NULL THEN
    PERFORM pgmemento.unregister_audit_table(old_table_name, old_schema_name);
  END IF;

  -- get audit_id_column name which was set in create_table_audit_id or in event trigger when renaming the table
  audit_id_column_name := current_setting('pgmemento.' || $2 || '.' || $1 || '.audit_id.t' || txid_current());

  -- get logging behavior which was set in create_table_audit_id or in event trigger when renaming the table
  log_data_settings := current_setting('pgmemento.' || $2 || '.' || $1 || '.log_data.t' || txid_current());

  -- now register table and corresponding columns in audit tables
  INSERT INTO pgmemento.audit_table_log
    (log_id, relid, schema_name, table_name, audit_id_column, log_old_data, log_new_data, txid_range)
  VALUES
    (table_log_id, pgmemento.get_table_oid($1, $2), $2, $1, audit_id_column_name,
     CASE WHEN split_part(log_data_settings, ',' ,1) = 'old=true' THEN TRUE ELSE FALSE END,
     CASE WHEN split_part(log_data_settings, ',' ,2) = 'new=true' THEN TRUE ELSE FALSE END,
     numrange(current_setting('pgmemento.t' || txid_current())::numeric, NULL, '(]'))
  RETURNING id INTO tab_id;

  -- insert columns of new audited table into 'audit_column_log'
  INSERT INTO pgmemento.audit_column_log
    (id, audit_table_id, column_name, ordinal_position, column_default, not_null, data_type, txid_range)
  (
    SELECT
      nextval('pgmemento.audit_column_log_id_seq') AS id,
      tab_id AS audit_table_id,
      a.attname AS column_name,
      a.attnum AS ordinal_position,
      pg_get_expr(d.adbin, d.adrelid, TRUE) AS column_default,
      a.attnotnull AS not_null,
      substr(
        format_type(a.atttypid, a.atttypmod),
        position('.' IN format_type(a.atttypid, a.atttypmod))+1,
        length(format_type(a.atttypid, a.atttypmod))
      ) AS data_type,
      numrange(current_setting('pgmemento.t' || txid_current())::numeric, NULL, '(]') AS txid_range
    FROM
      pg_attribute a
    LEFT JOIN
      pg_attrdef d
      ON (a.attrelid, a.attnum) = (d.adrelid, d.adnum)
    WHERE
      a.attrelid = pgmemento.get_table_oid($1, $2)
      AND a.attname <> audit_id_column_name
      AND a.attnum > 0
      AND NOT a.attisdropped
      ORDER BY a.attnum
  );

  -- rename unique constraint for audit_id column
  IF old_table_name IS NOT NULL AND old_schema_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE %I.%I RENAME CONSTRAINT %I TO %I',
      $2, $1, old_table_name || '_' || audit_id_column_name || '_key', $1 || '_' || audit_id_column_name || '_key');
  END IF;

  RETURN tab_id;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;


/**********************************************************
* LOGGING TRIGGER
*
* Define trigger on a table to fire events when
*  - a statement is executed
*  - rows are inserted, updated or deleted
*  - the table is truncated
***********************************************************/
-- create logging triggers for one table
CREATE OR REPLACE FUNCTION pgmemento.create_table_log_trigger(
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
  log_old_data BOOLEAN DEFAULT TRUE,
  log_new_data BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF VOID AS
$$
BEGIN
  IF EXISTS (
    SELECT
      1
    FROM
      pg_trigger
    WHERE
      tgrelid = pgmemento.get_table_oid($1, $2)
      AND tgname = 'pgmemento_transaction_trigger'
  ) THEN
    RETURN;
  ELSE
    /*
      statement level triggers
    */
    -- first trigger to be fired on each transaction
    EXECUTE format(
      'CREATE TRIGGER pgmemento_transaction_trigger
         BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE ON %I.%I
         FOR EACH STATEMENT EXECUTE PROCEDURE pgmemento.log_statement()',
         $2, $1);

    -- second trigger to be fired before truncate events if old data shall be logged
    IF $4 THEN
      EXECUTE format(
        'CREATE TRIGGER pgmemento_truncate_trigger
           BEFORE TRUNCATE ON %I.%I
           FOR EACH STATEMENT EXECUTE PROCEDURE pgmemento.log_truncate(%L)',
           $2, $1, $3);
    END IF;

    /*
      row level triggers
    */
    -- trigger to be fired after insert events
    EXECUTE format(
      'CREATE TRIGGER pgmemento_insert_trigger
         AFTER INSERT ON %I.%I
         FOR EACH ROW EXECUTE PROCEDURE pgmemento.log_insert(%L, %s, %s)',
         $2, $1, $3, CASE WHEN $4 THEN 'true' ELSE 'false' END, CASE WHEN $5 THEN 'true' ELSE 'false' END);

    -- trigger to be fired after update events
    EXECUTE format(
      'CREATE TRIGGER pgmemento_update_trigger
         AFTER UPDATE ON %I.%I
         FOR EACH ROW EXECUTE PROCEDURE pgmemento.log_update(%L, %s, %s)',
         $2, $1, $3, CASE WHEN $4 THEN 'true' ELSE 'false' END, CASE WHEN $5 THEN 'true' ELSE 'false' END);

    -- trigger to be fired after insert events
    EXECUTE format(
      'CREATE TRIGGER pgmemento_delete_trigger
         AFTER DELETE ON %I.%I
         FOR EACH ROW EXECUTE PROCEDURE pgmemento.log_delete(%L, %s)',
         $2, $1, $3, CASE WHEN $4 THEN 'true' ELSE 'false' END);
  END IF;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform create_table_log_trigger on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.create_schema_log_trigger(
  schemaname TEXT DEFAULT 'public'::text,
  log_old_data BOOLEAN DEFAULT TRUE,
  log_new_data BOOLEAN DEFAULT FALSE,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS SETOF VOID AS
$$
SELECT
  pgmemento.create_table_log_trigger(c.relname, $1, s.default_audit_id_column, $2, $3)
FROM
  pg_class c
JOIN
  pg_namespace n
  ON c.relnamespace = n.oid
 AND n.nspname = $1
JOIN
  pgmemento.audit_schema_log s
  ON s.schema_name = n.nspname
 AND upper(s.txid_range) IS NULL
WHERE
  c.relkind = 'r'
  AND c.relname <> ALL (COALESCE($4,'{}'::text[]));
$$
LANGUAGE sql
SECURITY DEFINER;

-- drop logging triggers for one table
CREATE OR REPLACE FUNCTION pgmemento.drop_table_log_trigger(
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text
  ) RETURNS SETOF VOID AS
$$
BEGIN
  EXECUTE format('DROP TRIGGER IF EXISTS pgmemento_delete_trigger ON %I.%I', $2, $1);
  EXECUTE format('DROP TRIGGER IF EXISTS pgmemento_update_trigger ON %I.%I', $2, $1);
  EXECUTE format('DROP TRIGGER IF EXISTS pgmemento_insert_trigger ON %I.%I', $2, $1);
  EXECUTE format('DROP TRIGGER IF EXISTS pgmemento_truncate_trigger ON %I.%I', $2, $1);
  EXECUTE format('DROP TRIGGER IF EXISTS pgmemento_transaction_trigger ON %I.%I', $2, $1);
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform drop_table_log_trigger on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.drop_schema_log_trigger(
  schema_name TEXT DEFAULT 'public'::text,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS SETOF VOID AS
$$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM pgmemento.audit_tables
     WHERE schemaname = $1
       AND tablename <> ALL (COALESCE($2,'{}'::text[]))
       AND tg_is_active
  ) THEN
    PERFORM
      pgmemento.drop_table_log_trigger(tablename, $1)
    FROM
      pgmemento.audit_tables
    WHERE
      schemaname = $1
      AND tablename <> ALL (COALESCE($2,'{}'::text[]))
      AND tg_is_active;

    PERFORM pgmemento.stop($1, $2);
  END IF;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* AUDIT ID COLUMN
*
* Add an extra audit column to a table to trace changes on
* rows over time.
***********************************************************/
-- add audit column to a table
CREATE OR REPLACE FUNCTION pgmemento.create_table_audit_id(
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text
  ) RETURNS SETOF VOID AS
$$
BEGIN
  -- log as 'add column' event, as it is not done by event triggers
  PERFORM pgmemento.log_table_event($1, $2, 'ADD AUDIT_ID');

  -- add audit column to table
  -- throws exception if it already exist
  EXECUTE format(
    'ALTER TABLE %I.%I ADD COLUMN %I BIGINT DEFAULT nextval(''pgmemento.audit_id_seq''::regclass) UNIQUE NOT NULL',
    $2, $1, $3);
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform create_table_audit_id on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.create_schema_audit_id(
  schemaname TEXT DEFAULT 'public'::text,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS SETOF VOID AS
$$
SELECT
  pgmemento.create_table_audit_id(c.relname, $1, s.default_audit_id_column)
FROM
  pg_class c
JOIN
  pg_namespace n
  ON c.relnamespace = n.oid
 AND n.nspname = $1
JOIN
  pgmemento.audit_schema_log s
  ON s.schema_name = n.nspname
 AND upper(s.txid_range) IS NULL
WHERE
  c.relkind = 'r'
  AND c.relname <> ALL (COALESCE($2,'{}'::text[]));
$$
LANGUAGE sql
SECURITY DEFINER;

-- drop audit column from a table
CREATE OR REPLACE FUNCTION pgmemento.drop_table_audit_id(
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text
  ) RETURNS SETOF VOID AS
$$
BEGIN
  -- drop audit column if it exists
  IF EXISTS (
    SELECT
      1
    FROM
      pg_attribute
    WHERE
      attrelid = pgmemento.get_table_oid($1, $2)
      AND attname = $3
      AND attislocal = 't'
      AND NOT attisdropped
  ) THEN
    EXECUTE format(
      'ALTER TABLE %I.%I DROP CONSTRAINT %I, DROP COLUMN %I',
      $2, $1, $1 || '_' || audit_id_column_name || '_key', $3);
  ELSE
    RETURN;
  END IF;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform drop_table_audit_id on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.drop_schema_audit_id(
  schema_name TEXT DEFAULT 'public'::text,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS SETOF VOID AS
$$
SELECT
  pgmemento.drop_table_audit_id(tablename, $1, audit_id_column)
FROM
  pgmemento.audit_tables
WHERE
  schemaname = $1
  AND tablename <> ALL (COALESCE($2,'{}'::text[]));
$$
LANGUAGE sql
SECURITY DEFINER;


/**********************************************************
* LOG TABLE STATE
*
* Function to log the whole content of a table or only
* for given columns.
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.column_array_to_column_list(columns TEXT[]) RETURNS TEXT AS
$$
SELECT
  array_to_string(array_agg(format('%L, %I', k, v)), ', ')
FROM
  unnest($1) k,
  unnest($1) v
WHERE
  k = v;
$$
LANGUAGE sql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION pgmemento.log_old_table_state(
  columns TEXT[],
  tablename TEXT,
  schemaname TEXT,
  table_event_key TEXT,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text
  ) RETURNS SETOF VOID AS
$$
BEGIN
  IF $1 IS NOT NULL AND array_length($1, 1) IS NOT NULL THEN
    -- log content of given columns
    EXECUTE format(
      'INSERT INTO pgmemento.row_log AS r (audit_id, event_key, old_data)
         SELECT %I, $1, jsonb_build_object('||pgmemento.column_array_to_column_list($1)||') AS content
           FROM %I.%I ORDER BY %I
       ON CONFLICT (audit_id, event_key)
       DO UPDATE SET
         old_data = COALESCE(excluded.old_data, ''{}''::jsonb) || COALESCE(r.old_data, ''{}''::jsonb)',
       $5, $3, $2, $5) USING $4;
  ELSE
    -- log content of entire table
    EXECUTE format(
      'INSERT INTO pgmemento.row_log (audit_id, event_key, old_data)
         SELECT %I, $1, to_jsonb(%I) AS content
           FROM %I.%I ORDER BY %I
       ON CONFLICT (audit_id, event_key)
       DO NOTHING',
       $5, $2, $3, $2, $5) USING $4;
  END IF;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;

CREATE OR REPLACE FUNCTION pgmemento.log_new_table_state(
  columns TEXT[],
  tablename TEXT,
  schemaname TEXT,
  table_event_key TEXT,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text
  ) RETURNS SETOF VOID AS
$$
BEGIN
  IF $1 IS NOT NULL AND array_length($1, 1) IS NOT NULL THEN
    -- log content of given columns
    EXECUTE format(
      'INSERT INTO pgmemento.row_log AS r (audit_id, event_key, new_data)
         SELECT %I, $1, jsonb_build_object('||pgmemento.column_array_to_column_list($1)||') AS content
           FROM %I.%I ORDER BY %I
       ON CONFLICT (audit_id, event_key)
       DO UPDATE SET new_data = COALESCE(r.new_data, ''{}''::jsonb) || COALESCE(excluded.new_data, ''{}''::jsonb)',
       $5, $3, $2, $5) USING $4;
  ELSE
    -- log content of entire table
    EXECUTE format(
      'INSERT INTO pgmemento.row_log r (audit_id, event_key, new_data)
         SELECT %I, $1, to_jsonb(%I) AS content
           FROM %I.%I ORDER BY %I
       ON CONFLICT (audit_id, event_key)
       DO UPDATE SET COALESCE(r.new_data, ''{}''::jsonb) || COALESCE(excluded.new_data, ''{}''::jsonb)',
       $5, $2, $3, $2, $5) USING $4;
  END IF;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* LOG TRANSACTION
*
* Function that write information of ddl and dml events into
* transaction_log and returns the transaction ID
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.log_transaction(current_txid BIGINT) RETURNS INTEGER AS
$$
DECLARE
  session_info_text TEXT;
  session_info_obj JSONB;
  transaction_log_id INTEGER;
BEGIN
  -- retrieve session_info set by client
  BEGIN
    session_info_text := current_setting('pgmemento.session_info');

    IF session_info_text IS NULL OR session_info_text = '' THEN
      session_info_obj := NULL;
    ELSE
      session_info_obj := session_info_text::jsonb;
    END IF;

    EXCEPTION
      WHEN undefined_object THEN
        session_info_obj := NULL;
      WHEN invalid_text_representation THEN
        BEGIN
          session_info_obj := to_jsonb(current_setting('pgmemento.session_info'));
        END;
      WHEN others THEN
        RAISE NOTICE 'Unable to parse session info: %', session_info_text;
        session_info_obj := NULL;
  END;

  -- try to log corresponding transaction
  INSERT INTO pgmemento.transaction_log
    (txid, txid_time, process_id, user_name, client_name, client_port, application_name, session_info)
  VALUES
    ($1, transaction_timestamp(), pg_backend_pid(), session_user, inet_client_addr(), inet_client_port(),
     current_setting('application_name'), session_info_obj
    )
  ON CONFLICT (txid_time, txid)
    DO NOTHING
  RETURNING id
  INTO transaction_log_id;

  IF transaction_log_id IS NOT NULL THEN
    PERFORM set_config('pgmemento.t' || $1, transaction_log_id::text, TRUE);
  ELSE
    transaction_log_id := current_setting('pgmemento.t' || $1)::int;
  END IF;

  RETURN transaction_log_id;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;

/**********************************************************
* LOG TABLE EVENT
*
* Function that write information of ddl and dml events into
* transaction_log and table_event_log and returns the event ID
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.log_table_event(
  tablename TEXT,
  schemaname TEXT,
  op_type TEXT
  ) RETURNS TEXT AS
$$
DECLARE
  txid_log_id INTEGER;
  stmt_ts TIMESTAMP WITH TIME ZONE := statement_timestamp();
  operation_id SMALLINT := pgmemento.get_operation_id($3);
  table_event_key TEXT;
BEGIN
  -- try to log corresponding transaction
  txid_log_id := pgmemento.log_transaction(txid_current());

  -- try to log corresponding table event
  -- on conflict do nothing
  INSERT INTO pgmemento.table_event_log
    (transaction_id, stmt_time, op_id, table_operation, table_name, schema_name, event_key)
  VALUES
    (txid_log_id, stmt_ts, operation_id, $3, $1, $2,
     concat_ws(';', extract(epoch from transaction_timestamp()), extract(epoch from stmt_ts), txid_current(), operation_id, $1, $2))
  ON CONFLICT (event_key)
    DO NOTHING
  RETURNING event_key
  INTO table_event_key;

  RETURN table_event_key;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* TRIGGER PROCEDURE log_statement
*
* Procedure that is called when a pgmemento_transaction_trigger
* is fired. Metadata of each transaction is written to the
* transaction_log table.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.log_statement() RETURNS trigger AS
$$
BEGIN
  PERFORM pgmemento.log_table_event(TG_TABLE_NAME, TG_TABLE_SCHEMA, TG_OP);
  RETURN NULL;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* TRIGGER PROCEDURE log_truncate
*
* Procedure that is called when a log_truncate_trigger is fired.
* Table pgmemento.row_log is filled up with entries of truncated table.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.log_truncate() RETURNS trigger AS
$$
BEGIN
  -- log the whole content of the truncated table in the row_log table
  PERFORM
    pgmemento.log_old_table_state('{}'::text[], TG_TABLE_NAME, TG_TABLE_SCHEMA, event_key, TG_ARGV[0])
  FROM
    pgmemento.table_event_log
  WHERE
    transaction_id = current_setting('pgmemento.t' || txid_current())::int
    AND table_name = TG_TABLE_NAME
    AND schema_name = TG_TABLE_SCHEMA
    AND op_id = 8;

  RETURN NULL;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* TRIGGER PROCEDURE log_insert
*
* Procedure that is called when a log_insert_trigger is fired.
* Table pgmemento.row_log is filled up with inserted entries
* without specifying the content.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.log_insert() RETURNS trigger AS
$$
DECLARE
  new_audit_id BIGINT;
BEGIN
  EXECUTE 'SELECT $1.' || TG_ARGV[0] USING NEW INTO new_audit_id;

  -- log inserted row ('old_data' column can be left blank)
  INSERT INTO pgmemento.row_log
    (audit_id, event_key, new_data)
  VALUES
    (new_audit_id,
     concat_ws(';', extract(epoch from transaction_timestamp()), extract(epoch from statement_timestamp()), txid_current(), pgmemento.get_operation_id(TG_OP), TG_TABLE_NAME, TG_TABLE_SCHEMA),
     CASE WHEN TG_ARGV[2] = 'true' THEN to_json(NEW) ELSE NULL END);

  RETURN NULL;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* TRIGGER PROCEDURE log_update
*
* Procedure that is called when a log_update_trigger is fired.
* Table pgmemento.row_log is filled up with updated entries
* but logging only the difference between OLD and NEW.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.log_update() RETURNS trigger AS
$$
DECLARE
  new_audit_id BIGINT;
  jsonb_diff_old JSONB;
  jsonb_diff_new JSONB;
BEGIN
  EXECUTE 'SELECT $1.' || TG_ARGV[0] USING NEW INTO new_audit_id;

  -- log values of updated columns for the processed row
  -- therefore, a diff between OLD and NEW is necessary
  IF TG_ARGV[1] = 'true' THEN
    SELECT COALESCE(
      (SELECT
         ('{' || string_agg(to_json(key) || ':' || value, ',') || '}')
       FROM
         jsonb_each(to_jsonb(OLD))
       WHERE
         to_jsonb(NEW) ->> key IS DISTINCT FROM to_jsonb(OLD) ->> key
      ),
      '{}')::jsonb INTO jsonb_diff_old;
  END IF;

  IF TG_ARGV[2] = 'true' THEN
    -- switch the diff to only get the new values
    SELECT COALESCE(
      (SELECT
         ('{' || string_agg(to_json(key) || ':' || value, ',') || '}')
       FROM
         jsonb_each(to_jsonb(NEW))
       WHERE
         to_jsonb(OLD) ->> key IS DISTINCT FROM to_jsonb(NEW) ->> key
      ),
      '{}')::jsonb INTO jsonb_diff_new;
  END IF;

  IF jsonb_diff_old <> '{}'::jsonb OR jsonb_diff_new <> '{}'::jsonb THEN
    -- log delta, on conflict concat logs, for old_data oldest should overwrite, for new_data vice versa
    INSERT INTO pgmemento.row_log AS r
      (audit_id, event_key, old_data, new_data)
    VALUES
      (new_audit_id,
       concat_ws(';', extract(epoch from transaction_timestamp()), extract(epoch from statement_timestamp()), txid_current(), pgmemento.get_operation_id(TG_OP), TG_TABLE_NAME, TG_TABLE_SCHEMA),
       jsonb_diff_old, jsonb_diff_new)
    ON CONFLICT (audit_id, event_key)
    DO UPDATE SET
      old_data = COALESCE(excluded.old_data, '{}'::jsonb) || COALESCE(r.old_data, '{}'::jsonb),
      new_data = COALESCE(r.new_data, '{}'::jsonb) || COALESCE(excluded.new_data, '{}'::jsonb);
  END IF;

  RETURN NULL;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* TRIGGER PROCEDURE log_delete
*
* Procedure that is called when a log_delete_trigger is fired.
* Table pgmemento.row_log is filled up with deleted entries
* including the complete row as JSONB.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.log_delete() RETURNS trigger AS
$$
DECLARE
  old_audit_id BIGINT;
BEGIN
  EXECUTE 'SELECT $1.' || TG_ARGV[0] USING OLD INTO old_audit_id;

  -- log content of the entire row in the row_log table
  INSERT INTO pgmemento.row_log
    (audit_id, event_key, old_data)
  VALUES
    (old_audit_id,
     concat_ws(';', extract(epoch from transaction_timestamp()), extract(epoch from statement_timestamp()), txid_current(), pgmemento.get_operation_id(TG_OP), TG_TABLE_NAME, TG_TABLE_SCHEMA),
     CASE WHEN TG_ARGV[1] = 'true' THEN to_json(OLD) ELSE NULL END);

  RETURN NULL;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* LOG TABLE BASELINE
*
* Log table content in the row_log table (as inserted values)
* to have a baseline for table versioning.
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.log_table_baseline(
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
  log_new_data BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF VOID AS
$$
DECLARE
  is_empty INTEGER := 0;
  table_event_key TEXT;
  pkey_columns TEXT := '';
BEGIN
  -- first, check if table is not empty
  EXECUTE format('SELECT 1 FROM %I.%I LIMIT 1', $2, $1) INTO is_empty;

  IF is_empty <> 0 THEN
    RAISE NOTICE 'Log existing data in table %.% as inserted', $1, $2;
    table_event_key := pgmemento.log_table_event($1, $2, 'INSERT');

    -- fill row_log table
    IF table_event_key IS NOT NULL THEN
      -- get the primary key columns
      SELECT
        array_to_string(array_agg('t.' || pga.attname),',') INTO pkey_columns
      FROM
        pg_index pgi,
        pg_class pgc,
        pg_attribute pga
      WHERE
        pgc.oid = pgmemento.get_table_oid($1, $2)
        AND pgi.indrelid = pgc.oid
        AND pga.attrelid = pgc.oid
        AND pga.attnum = ANY(pgi.indkey)
        AND pgi.indisprimary;

      IF pkey_columns IS NOT NULL THEN
        pkey_columns := ' ORDER BY ' || pkey_columns;
      ELSE
        pkey_columns := ' ORDER BY t.' || $3;
      END IF;

      EXECUTE format(
        'INSERT INTO pgmemento.row_log (audit_id, event_key'
         || CASE WHEN $4 THEN ', new_data' ELSE '' END
         || ') '
         || 'SELECT t.' || $3 || ', $1'
         || CASE WHEN $4 THEN ', to_json(t.*) ' ELSE ' ' END
         || 'FROM %I.%I t '
         || 'LEFT JOIN pgmemento.row_log r ON r.audit_id = t.' || $3
         || ' WHERE r.audit_id IS NULL' || pkey_columns
         || ' ON CONFLICT (audit_id, event_key) DO NOTHING',
         $2, $1) USING table_event_key;
    END IF;
  END IF;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform log_table_baseline on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.log_schema_baseline(
  audit_schema_name TEXT DEFAULT 'public'::text
  ) RETURNS SETOF VOID AS
$$
SELECT
  pgmemento.log_table_baseline(a.table_name, a.schema_name, a.audit_id_column, a.log_new_data)
FROM
  pgmemento.audit_schema_log s,
  pgmemento.audit_table_log a,
  pgmemento.audit_tables_dependency d
WHERE
  s.schema_name = $1
  AND s.schema_name = a.schema_name
  AND a.schema_name = d.schemaname
  AND a.table_name = d.tablename
  AND upper(a.txid_range) IS NULL
  AND lower(a.txid_range) IS NOT NULL
ORDER BY
  d.depth;
$$
LANGUAGE sql STRICT
SECURITY DEFINER;


/**********************************************************
* ENABLE/DISABLE PGMEMENTO
*
* Enables/disables pgMemento for a specified tabl
e/schema.
***********************************************************/
-- create pgMemento for one table
CREATE OR REPLACE FUNCTION pgmemento.create_table_audit(
  tablename TEXT,
  schemaname TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
  log_old_data BOOLEAN DEFAULT TRUE,
  log_new_data BOOLEAN DEFAULT FALSE,
  log_state BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF VOID AS
$$
DECLARE
  except_tables TEXT[] DEFAULT '{}';
BEGIN
  -- check if pgMemento is already initialized for schema
  IF NOT EXISTS (
    SELECT 1
      FROM pgmemento.audit_schema_log
     WHERE schema_name = $2
       AND upper(txid_range) IS NULL
  ) THEN
    SELECT
      array_agg(c.relname)
    INTO
      except_tables
    FROM
      pg_class c
    JOIN
      pg_namespace n
      ON c.relnamespace = n.oid
    WHERE
      n.nspname = $2
      AND c.relname <> $1
      AND c.relkind = 'r';

    PERFORM pgmemento.create_schema_audit($2, $3, $4, $5, $6, FALSE, except_tables);
    RETURN;
  END IF;

  -- remember audit_id_column when registering table in audit_table_log later
  PERFORM set_config('pgmemento.' || $2 || '.' || $1 || '.audit_id.t' || txid_current(), $3, TRUE);

  -- remember logging behavior when registering table in audit_table_log later
  PERFORM set_config('pgmemento.' || $2 || '.' || $1 || '.log_data.t' || txid_current(),
    CASE WHEN log_old_data THEN 'old=true,' ELSE 'old=false,' END ||
    CASE WHEN log_new_data THEN 'new=true' ELSE 'new=false' END, TRUE);

  -- create log trigger
  PERFORM pgmemento.create_table_log_trigger($1, $2, $3, $4, $5);

  -- add audit_id column
  PERFORM pgmemento.create_table_audit_id($1, $2, $3);

  -- log existing table content as inserted
  IF $6 THEN
    PERFORM pgmemento.log_table_baseline($1, $2, $3, $5);
  END IF;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform create_table_audit on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.create_schema_audit(
  schemaname TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
  log_old_data BOOLEAN DEFAULT TRUE,
  log_new_data BOOLEAN DEFAULT FALSE,
  log_state BOOLEAN DEFAULT FALSE,
  trigger_create_table BOOLEAN DEFAULT FALSE,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS SETOF VOID AS
$$
DECLARE
  current_txid_range numrange;
BEGIN
  -- check if schema is already audited
  SELECT txid_range INTO current_txid_range
    FROM pgmemento.audit_schema_log
   WHERE schema_name = $1;

  -- if not initialize pgMemento, this will also call create_schema_audit
  IF current_txid_range IS NULL THEN
    PERFORM pgmemento.init($1, $2, $3, $4, $5, $6, $7);
    RETURN;
  ELSE
    IF upper(current_txid_range) IS NOT NULL THEN
      RAISE NOTICE 'Schema has been audited before. pgMemento will only be started.';
      PERFORM pgmemento.start($1, $2, $3, $4, $6, $7);
    END IF;
  END IF;

  PERFORM
    pgmemento.create_table_audit(c.relname, $1, $2, $3, $4, $5)
  FROM
    pg_class c
  JOIN
    pg_namespace n
    ON c.relnamespace = n.oid
  LEFT JOIN pgmemento.audit_tables at
    ON at.tablename = c.relname
   AND at.schemaname = n.nspname
   AND NOT at.tg_is_active
  WHERE
    n.nspname = $1
    AND c.relkind = 'r'
    AND c.relname <> ALL (COALESCE($7,'{}'::text[]))
    AND at.tg_is_active IS NULL;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;

-- drop pgMemento for one table
CREATE OR REPLACE FUNCTION pgmemento.drop_table_audit(
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
  log_state BOOLEAN DEFAULT TRUE,
  drop_log BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF VOID AS
$$
DECLARE
  table_event_key TEXT;
BEGIN
  -- first drop log trigger
  PERFORM pgmemento.drop_table_log_trigger($1, $2);

  -- log the whole content of the table to keep the reference between audit_id and table rows
  IF $4 THEN
    -- log event as event triggers will walk around anything related to the audit_id
    table_event_key := pgmemento.log_table_event($1, $2, 'TRUNCATE');

    -- log the whole content of the table to keep the reference between audit_id and table rows
    PERFORM pgmemento.log_old_table_state('{}'::text[], $1, $2, table_event_key, $3);
  END IF;

  -- log event as event triggers will walk around anything related to the audit_id
  table_event_key := pgmemento.log_table_event($1, $2, 'DROP AUDIT_ID');

  -- update audit_table_log and audit_column_log
  PERFORM pgmemento.unregister_audit_table($1, $2);

  -- remove all logs related to given table
  IF $5 THEN
    PERFORM pgmemento.delete_audit_table_log($1, $2);
  END IF;

  -- drop audit_id column
  PERFORM pgmemento.drop_table_audit_id($1, $2, $3);
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform drop_table_audit on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.drop_schema_audit(
  schema_name TEXT DEFAULT 'public'::text,
  log_state BOOLEAN DEFAULT TRUE,
  drop_log BOOLEAN DEFAULT FALSE,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS SETOF VOID AS
$$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM pgmemento.audit_tables
     WHERE schemaname = $1
       AND tablename <> ALL (COALESCE($4,'{}'::text[]))
  ) THEN
    PERFORM
      pgmemento.drop_table_audit(tablename, $1, audit_id_column, $2, $3)
    FROM
      pgmemento.audit_tables
    WHERE
      schemaname = $1
      AND tablename <> ALL (COALESCE($4,'{}'::text[]));

    PERFORM pgmemento.drop($1, $2, $3, $4);
  END IF;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;




-- LOG_UTIL.sql
--
-- Author:      Felix Kunde <felix-kunde@gmx.de>
--
--              This script is free software under the LGPL Version 3
--              See the GNU Lesser General Public License at
--              http://www.gnu.org/copyleft/lgpl.html
--              for more details.
-------------------------------------------------------------------------------
-- About:
-- This script provides utility functions for pgMemento and creates VIEWs
-- for document auditing and table dependencies
--
-------------------------------------------------------------------------------
--
-- ChangeLog:
--
-- Version | Date       | Description                                  | Author
-- 0.7.8     2021-03-21   fix jsonb_unroll_for_update for array values   FKun
-- 0.7.7     2020-07-28   new route function to get column list          FKun
-- 0.7.6     2020-04-28   change new_data in row_log on update/delete    FKun
--                        cover row_log when deleting events
-- 0.7.5     2020-03-23   add audit_id_column to audit_table_check       FKun
-- 0.7.4     2020-03-07   set SECURITY DEFINER where log tables are      FKun
--                        touched
-- 0.7.3     2020-02-29   reflect new schema of row_log table            FKun
-- 0.7.2     2020-02-09   reflect changes on schema and triggers         FKun
-- 0.7.1     2020-02-08   stop using trim_outer_quotes                   FKun
-- 0.7.0     2019-03-23   reflect schema changes in UDFs                 FKun
-- 0.6.4     2019-03-23   audit_table_check can handle relid mismatch    FKun
-- 0.6.3     2018-11-20   new helper function to revert updates with     FKun
--                        composite data types
-- 0.6.2     2018-11-05   delete_table_event_log now takes OID           FKun
-- 0.6.1     2018-11-02   new functions to get historic table layouts    FKun
-- 0.6.0     2018-10-28   new function to update a key in logs           FKun
--                        new value filter in delete_key function
-- 0.5.1     2018-10-24   audit_table_check function moved here          FKun
-- 0.5.0     2018-07-16   reflect changes in transaction_id handling     FKun
-- 0.4.2     2017-07-26   new function to remove a key from all logs     FKun
-- 0.4.1     2017-04-11   moved VIEWs to SETUP.sql & added jsonb_merge   FKun
-- 0.4.0     2017-03-06   new view for table dependencies                FKun
-- 0.3.0     2016-04-14   reflected changes in log tables                FKun
-- 0.2.1     2016-04-05   additional column in audit_tables view         FKun
-- 0.2.0     2016-02-15   get txids done right                           FKun
-- 0.1.0     2015-06-20   initial commit                                 FKun
--

/**********************************************************
* C-o-n-t-e-n-t:
*
* AGGREGATE:
*   jsonb_merge(jsonb)
*
* FUNCTIONS:
*   audit_table_check(IN tid INTEGER, IN tab_name TEXT, IN tab_schema TEXT,
*     OUT table_log_id INTEGER, OUT log_tab_name TEXT, OUT log_tab_schema TEXT, OUT log_tab_id INTEGER,
*     OUT recent_tab_name TEXT, OUT recent_tab_schema TEXT, OUT recent_tab_id INTEGER) RETURNS RECORD
*   delete_audit_table_log(tablename TEXT, schemaname TEXT DEFAULT 'public'::text) RETURNS SETOF INTEGER
*   delete_key(aid BIGINT, key_name TEXT, old_value anyelement) RETURNS SETOF BIGINT
*   delete_table_event_log(tablename TEXT, schemaname TEXT DEFAULT 'public'::text) RETURNS SETOF INTEGER
*   delete_table_event_log(tid INTEGER, tablename TEXT, schemaname TEXT DEFAULT 'public'::text) RETURNS SETOF INTEGER
*   delete_txid_log(tid INTEGER) RETURNS INTEGER
*   get_column_list(start_from_tid INTEGER, end_at_tid INTEGER, table_log_id INTEGER,
*     table_name TEXT, schema_name TEXT DEFAULT 'public'::text, all_versions BOOLEAN DEFAULT FALSE,
*     OUT column_name TEXT, OUT column_count INTEGER, OUT data_type TEXT, OUT ordinal_position INTEGER,
*     OUT txid_range numrange) RETURNS SETOF RECORD
*   get_column_list_by_txid(tid INTEGER, table_name TEXT, schema_name TEXT DEFAULT 'public'::text,
*     OUT column_name TEXT, OUT data_type TEXT, OUT ordinal_position INTEGER) RETURNS SETOF RECORD
*   get_column_list_by_txid_range(start_from_tid INTEGER, end_at_tid INTEGER, table_log_id INTEGER,
*     OUT column_name TEXT, OUT column_count INTEGER, OUT data_type TEXT, OUT ordinal_position INTEGER,
*     OUT txid_range numrange) RETURNS SETOF RECORD
*   get_max_txid_to_audit_id(aid BIGINT) RETURNS INTEGER
*   get_min_txid_to_audit_id(aid BIGINT) RETURNS INTEGER
*   get_txids_to_audit_id(aid BIGINT) RETURNS SETOF INTEGER
*   jsonb_unroll_for_update(path TEXT, nested_value JSONB, complex_typname TEXT) RETURNS TEXT
*   update_key(aid BIGINT, path_to_key_name TEXT[], old_value anyelement, new_value anyelement) RETURNS SETOF BIGINT
*
***********************************************************/

/**********************************************************
* JSONB MERGE
*
* Custom aggregate function to merge several JSONB logs
* into one JSONB element eliminating redundant keys
***********************************************************/
CREATE AGGREGATE pgmemento.jsonb_merge(jsonb)
(
    sfunc = jsonb_concat(jsonb, jsonb),
    stype = jsonb,
    initcond = '{}'
);


/**********************************************************
* JSONB UNROLL
*
* Helper function to revert updates with composite datatypes
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.jsonb_unroll_for_update(
  path TEXT,
  nested_value JSONB,
  complex_typname TEXT
  ) RETURNS TEXT AS
$$
SELECT
  string_agg(set_columns,', ')
FROM (
  SELECT
    CASE WHEN jsonb_typeof(j.value) = 'object' AND p.typname IS NOT NULL THEN
      pgmemento.jsonb_unroll_for_update($1 || '.' || quote_ident(j.key), j.value, p.typname)
    ELSE
      $1 || '.' || quote_ident(j.key) || '=' ||
      CASE WHEN jsonb_typeof(j.value) = 'array' THEN
        quote_nullable(translate($2 ->> j.key, '[]', '{}'))
      ELSE
        quote_nullable($2 ->> j.key)
      END
    END AS set_columns
  FROM
    jsonb_each($2) j
  LEFT JOIN
    pg_attribute a
    ON a.attname = j.key
   AND jsonb_typeof(j.value) = 'object'
  LEFT JOIN
    pg_class c
    ON c.oid = a.attrelid
  LEFT JOIN
    pg_type t
    ON t.typrelid = c.oid
   AND t.typname = $3
  LEFT JOIN
    pg_type p
    ON p.typname = format_type(a.atttypid, a.atttypmod)
   AND p.typcategory = 'C'
) u
$$
LANGUAGE sql STRICT;


/**********************************************************
* GET TRANSACTION ID
*
* Simple functions to return the transaction_id related to
* certain database entities
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.get_txids_to_audit_id(aid BIGINT) RETURNS SETOF INTEGER AS
$$
SELECT
  t.id
FROM
  pgmemento.transaction_log t
JOIN
  pgmemento.table_event_log e
  ON e.transaction_id = t.id
JOIN
  pgmemento.row_log r
  ON r.event_key = e.event_key
 AND r.audit_id = $1;
$$
LANGUAGE sql STABLE STRICT;

CREATE OR REPLACE FUNCTION pgmemento.get_min_txid_to_audit_id(aid BIGINT) RETURNS INTEGER AS
$$
SELECT
  min(t.id)
FROM
  pgmemento.transaction_log t
JOIN
  pgmemento.table_event_log e
  ON e.transaction_id = t.id
JOIN
  pgmemento.row_log r
  ON r.event_key = e.event_key
 AND r.audit_id = $1;
$$
LANGUAGE sql STABLE STRICT;

CREATE OR REPLACE FUNCTION pgmemento.get_max_txid_to_audit_id(aid BIGINT) RETURNS INTEGER AS
$$
SELECT
  max(t.id)
FROM
  pgmemento.transaction_log t
JOIN
  pgmemento.table_event_log e
  ON e.transaction_id = t.id
JOIN
  pgmemento.row_log r
  ON r.event_key = e.event_key
 AND r.audit_id = $1;
$$
LANGUAGE sql STABLE STRICT;


/**********************************************************
* DELETE LOGS
*
* Delete log information of a given transaction, event or
* audited tables / columns
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.delete_txid_log(tid INTEGER) RETURNS INTEGER AS
$$
DELETE FROM
  pgmemento.transaction_log
WHERE
  id = $1
RETURNING
  id;
$$
LANGUAGE sql STRICT
SECURITY DEFINER;

CREATE OR REPLACE FUNCTION pgmemento.delete_table_event_log(
  tid INTEGER,
  tablename TEXT,
  schemaname TEXT DEFAULT 'public'::text
  ) RETURNS SETOF INTEGER AS
$$
WITH delete_table_event AS (
  DELETE FROM
    pgmemento.table_event_log
  WHERE
    transaction_id = $1
    AND table_name = $2
    AND schema_name = $3
  RETURNING
    id, event_key
), delete_row_log_event AS (
  DELETE FROM
    pgmemento.row_log r
  USING
    delete_table_event dte
  WHERE
    dte.event_key = r.event_key
)
SELECT
  id
FROM
  delete_table_event;
$$
LANGUAGE sql STRICT
SECURITY DEFINER;

CREATE OR REPLACE FUNCTION pgmemento.delete_table_event_log(
  tablename TEXT,
  schemaname TEXT DEFAULT 'public'::text
  ) RETURNS SETOF INTEGER AS
$$
WITH delete_table_event AS (
  DELETE FROM
    pgmemento.table_event_log
  WHERE
    table_name = $1
    AND schema_name = $2
  RETURNING
    id, event_key
), delete_row_log_event AS (
  DELETE FROM
    pgmemento.row_log r
  USING
    delete_table_event dte
  WHERE
    dte.event_key = r.event_key
)
SELECT
  id
FROM
  delete_table_event;
$$
LANGUAGE sql STRICT
SECURITY DEFINER;

CREATE OR REPLACE FUNCTION pgmemento.delete_audit_table_log(
  tablename TEXT,
  schemaname TEXT DEFAULT 'public'::text
  ) RETURNS SETOF INTEGER AS
$$
DECLARE
  table_log_id INTEGER;
BEGIN
  SELECT
    log_id
  INTO
    table_log_id
  FROM
    pgmemento.audit_table_log
  WHERE
    table_name = $1
    AND schema_name = $2
    AND upper(txid_range) IS NOT NULL;

  -- only allow delete if table has already been dropped
  IF table_log_id IS NOT NULL THEN
    -- remove corresponding table events from event log
    PERFORM
      pgmemento.delete_table_event_log(table_name, schema_name)
    FROM
      pgmemento.audit_table_log
    WHERE
      log_id = table_log_id;

    RETURN QUERY
      DELETE FROM
        pgmemento.audit_table_log
      WHERE
        log_id = table_log_id
        AND upper(txid_range) IS NOT NULL
      RETURNING
        id;
  ELSE
    RAISE NOTICE 'Either audit table is not found or the table still exists.';
  END IF;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;


/**********************************************************
* DATA CORRECTION
*
* Functions to delete or update a value for a given key
* inside the audit trail
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.delete_key(
  aid BIGINT,
  key_name TEXT,
  old_value anyelement
  ) RETURNS SETOF BIGINT AS
$$
WITH find_log AS (
  SELECT
    id AS row_log_id,
    event_key AS log_event,
    new_data AS new_log
  FROM
    pgmemento.row_log
  WHERE
    audit_id = $1
    AND old_data @> jsonb_build_object($2, $3)
),
remove_key AS (
  UPDATE
    pgmemento.row_log r
  SET
    old_data = r.old_data - $2,
    new_data = r.new_data - $2
  FROM
    find_log f
  WHERE
    r.id = f.row_log_id
  RETURNING
    r.id
),
remove_prev_new_key AS (
  UPDATE
    pgmemento.row_log r
  SET
    new_data = r.new_data - $2
  FROM
    find_log f
  WHERE
    r.audit_id = $1
    AND r.event_key < f.log_event
    AND r.new_data @> jsonb_build_object($2, $3)
    AND f.new_log IS NULL
  RETURNING
    r.id
),
update_prev_new_key AS (
  UPDATE
    pgmemento.row_log r
  SET
    new_data = jsonb_set(new_data, ARRAY[$2], f.new_log -> $2, FALSE)
  FROM
    find_log f
  WHERE
    r.audit_id = $1
    AND r.event_key < f.log_event
    AND r.new_data @> jsonb_build_object($2, $3)
    AND f.new_log IS NOT NULL
  RETURNING
    r.id
)
SELECT id FROM (
  SELECT id FROM remove_key
  UNION
  SELECT id FROM remove_prev_new_key
  UNION
  SELECT id FROM update_prev_new_key
) dlog
ORDER BY id;
$$
LANGUAGE sql
SECURITY DEFINER;

CREATE OR REPLACE FUNCTION pgmemento.update_key(
  aid BIGINT,
  path_to_key_name TEXT[],
  old_value anyelement,
  new_value anyelement
  ) RETURNS SETOF BIGINT AS
$$
WITH update_old_key AS (
  UPDATE
    pgmemento.row_log
  SET
    old_data = jsonb_set(old_data, $2, to_jsonb($4), FALSE)
  WHERE
    audit_id = $1
    AND old_data @> jsonb_build_object($2[1], $3)
  RETURNING
    id
), update_new_key AS (
  UPDATE
    pgmemento.row_log
  SET
    new_data = jsonb_set(new_data, $2, to_jsonb($4), FALSE)
  WHERE
    audit_id = $1
    AND new_data @> jsonb_build_object($2[1], $3)
  RETURNING
    id
)
SELECT id FROM (
  SELECT id FROM update_old_key
  UNION
  SELECT id FROM update_new_key
) ulog
ORDER BY id;
$$
LANGUAGE sql
SECURITY DEFINER;


/**********************************************************
* AUDIT TABLE CHECK
*
* Helper function to check if requested table has existed
* before tid happened and if the name has been renamed
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.audit_table_check(
  IN tid INTEGER,
  IN tab_name TEXT,
  IN tab_schema TEXT,
  OUT table_log_id INTEGER,
  OUT log_tab_name TEXT,
  OUT log_tab_schema TEXT,
  OUT log_audit_id_column TEXT,
  OUT log_tab_id INTEGER,
  OUT recent_tab_name TEXT,
  OUT recent_tab_schema TEXT,
  OUT recent_audit_id_column TEXT,
  OUT recent_tab_id INTEGER
  ) RETURNS RECORD AS
$$
BEGIN
  -- get recent and possible previous parameter for audited table
  SELECT
    a_old.log_id,
    a_old.table_name,
    a_old.schema_name,
    a_old.audit_id_column,
    a_old.id,
    a_new.table_name,
    a_new.schema_name,
    a_new.audit_id_column,
    a_new.id
  INTO
    table_log_id,
    log_tab_name,
    log_tab_schema,
    log_audit_id_column,
    log_tab_id,
    recent_tab_name,
    recent_tab_schema,
    recent_audit_id_column,
    recent_tab_id
  FROM
    pgmemento.audit_table_log a_new
  LEFT JOIN
    pgmemento.audit_table_log a_old
    ON a_old.log_id = a_new.log_id
   AND a_old.txid_range @> $1::numeric
  WHERE
    a_new.table_name = $2
    AND a_new.schema_name = $3
    AND upper(a_new.txid_range) IS NULL
    AND lower(a_new.txid_range) IS NOT NULL;

  -- if table does not exist use name to query logs
  IF recent_tab_name IS NULL THEN
    SELECT
      log_id,
      table_name,
      schema_name,
      audit_id_column,
      id
    INTO
      table_log_id,
      log_tab_name,
      log_tab_schema,
      log_audit_id_column,
      log_tab_id
    FROM
      pgmemento.audit_table_log
    WHERE
      table_name = $2
      AND schema_name = $3
      AND txid_range @> $1::numeric;
  END IF;
END;
$$
LANGUAGE plpgsql STABLE STRICT;


/**********************************************************
* GET COLUMN LIST BY TXID (RANGE)
*
* Returns column details of an audited table that have
* existed either before a given transaction ID or within
* a given ID range. When querying by range all different
* versions of a column appear in the result set. To avoid
* ambiguity a counter is returned as well.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.get_column_list_by_txid(
  tid INTEGER,
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  OUT column_name TEXT,
  OUT data_type TEXT,
  OUT ordinal_position INTEGER
  ) RETURNS SETOF RECORD AS
$$
SELECT
  c.column_name,
  c.data_type,
  c.ordinal_position
FROM
  pgmemento.audit_column_log c
JOIN
  pgmemento.audit_table_log t
  ON t.id = c.audit_table_id
WHERE
  t.table_name = $2
  AND t.schema_name = $3
  AND t.txid_range @> $1::numeric
  AND c.txid_range @> $1::numeric;
$$
LANGUAGE sql STABLE STRICT;

CREATE OR REPLACE FUNCTION pgmemento.get_column_list_by_txid_range(
  start_from_tid INTEGER,
  end_at_tid INTEGER,
  table_log_id INTEGER,
  OUT column_name TEXT,
  OUT column_count INTEGER,
  OUT data_type TEXT,
  OUT ordinal_position INTEGER,
  OUT txid_range numrange
  ) RETURNS SETOF RECORD AS
$$
SELECT
  column_name,
  (row_number() OVER (PARTITION BY column_name))::int AS column_count,
  data_type,
  ordinal_position,
  txid_range
FROM (
  SELECT
    c.column_name,
    c.data_type,
    c.ordinal_position,
    numrange(min(lower(c.txid_range)),max(COALESCE(upper(c.txid_range),$2::numeric))) AS txid_range
  FROM
    pgmemento.audit_column_log c
  JOIN
    pgmemento.audit_table_log t
    ON t.id = c.audit_table_id
  WHERE
    t.log_id = $3
    AND t.txid_range && numrange(1::numeric, $2::numeric)
    AND c.txid_range && numrange(1::numeric, $2::numeric)
  GROUP BY
    c.column_name,
    c.data_type,
    c.ordinal_position
  ORDER BY
    c.ordinal_position
) t;
$$
LANGUAGE sql STABLE STRICT;

CREATE OR REPLACE FUNCTION pgmemento.get_column_list(
  start_from_tid INTEGER,
  end_at_tid INTEGER,
  table_log_id INTEGER,
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  all_versions BOOLEAN DEFAULT FALSE,
  OUT column_name TEXT,
  OUT column_count INTEGER,
  OUT data_type TEXT,
  OUT ordinal_position INTEGER,
  OUT txid_range numrange
  ) RETURNS SETOF RECORD AS
$$
BEGIN
  IF $6 THEN
    RETURN QUERY
      SELECT t.column_name, t.column_count, t.data_type, t.ordinal_position, t.txid_range
        FROM pgmemento.get_column_list_by_txid_range($1, $2, $3) t;
  ELSE
    RETURN QUERY
      SELECT t.column_name, NULL::int, t.data_type, t.ordinal_position, NULL::numrange
        FROM pgmemento.get_column_list_by_txid($2, $4, $5) t;
  END IF;
END;
$$
LANGUAGE plpgsql STABLE;




-- DDL_LOG.sql
--
-- Author:      Felix Kunde <felix-kunde@gmx.de>
--
--              This script is free software under the LGPL Version 3
--              See the GNU Lesser General Public License at
--              http://www.gnu.org/copyleft/lgpl.html
--              for more details.
-------------------------------------------------------------------------------
-- About:
-- This script provides functions to track table changes in all database
-- schemas using event triggers.
-------------------------------------------------------------------------------
--
-- ChangeLog:
--
-- Version | Date       | Description                                    | Author
-- 0.7.9     2021-12-23   session variables starting with letter           ol-teuto
-- 0.7.8     2020-04-13   remove txid from log_table_event                 FKun
-- 0.7.7     2020-04-05   add tags CREATE TABLE AS and SELECT INTO         FKun
-- 0.7.6     2020-03-29   reflect that logging old data is configurable    FKun
-- 0.7.5     2020-03-23   use audit_schema_log to check audit config       FKun
-- 0.7.4     2020-03-07   set SECURITY DEFINER where log tables are used   FKun
-- 0.7.3     2020-02-29   add triggers to log new data in row_log          FKun
-- 0.7.2     2020-02-09   reflect changes on schema and triggers           FKun
-- 0.7.1     2019-02-08   refactoring with new split_table_from_query      FKun
-- 0.7.0     2019-04-14   reflect schema changes in UDFs and VIEWs         FKun
-- 0.6.9     2019-02-24   new function flatten_ddl to remove comments      FKun
-- 0.6.8     2019-02-14   permit drop audit_id in pre alter trigger        FKun
-- 0.6.7     2019-02-09   fetch_ident: improved parsing of DDL context     FKun
-- 0.6.6     2018-11-19   log ADD COLUMN events in pre alter trigger       FKun
-- 0.6.5     2018-11-10   better treatment of dropping audit_id column     FKun
-- 0.6.4     2018-11-01   reflect range bounds change in audit tables      FKun
-- 0.6.3     2018-10-25   bool argument in create_schema_event_trigger     FKun
-- 0.6.2     2018-09-24   altering or dropping multiple columns at once    FKun
--                        produces only one JSONB log
-- 0.6.1     2018-07-24   RENAME events now appear in table_event_log      FKun
-- 0.6.0     2018-07-16   now calling log_table_event for ddl events       FKun
-- 0.5.1     2017-08-08   DROP TABLE/SCHEMA events log data as truncated   FKun
-- 0.5.0     2017-07-25   improved processing of DDL events                FKun
-- 0.4.1     2017-07-18   now using register functions from SETUP          FKun
-- 0.4.0     2017-07-12   reflect changes to audit_column_log table        FKun
-- 0.3.2     2017-04-10   log also CREATE/DROP TABLE and ADD COLUMN        FKun
--                        event in log tables (no data logging)
-- 0.3.1     2017-03-31   data logging before ALTER COLUMN events          FKun
-- 0.3.0     2017-03-15   data logging before DDL drop events              FKun
-- 0.2.0     2017-03-11   update to Pg9.5 and adding more trigger          FKun
-- 0.1.0     2016-04-14   initial commit                                   FKun
--

/**********************************************************
* C-o-n-t-e-n-t:
*
* FUNCTIONS:
*   create_schema_event_trigger(trigger_create_table BOOLEAN DEFAULT FALSE) RETURNS SETOF VOID
*   drop_schema_event_trigger() RETURNS SETOF VOID
*   fetch_ident(context TEXT, fetch_count INTEGER DEFAULT 1) RETURNS TEXT
*   flatten_ddl(ddl_command TEXT) RETURNS TEXT
*   get_ddl_from_context(stack TEXT) RETURNS TEXT
*   modify_ddl_log_tables(tablename TEXT, schemaname TEXT, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text) RETURNS SETOF VOID
*   split_table_from_query(INOUT query TEXT, OUT audit_table_name TEXT, OUT audit_schema_name TEXT,
*     OUT audit_table_log_id INTEGER, OUT audit_id_column_name TEXT, OUT audit_old_data BOOLEAN) RETURNS RECORD AS
*
* TRIGGER FUNCTIONS:
*   schema_drop_pre_trigger() RETURNS event_trigger
*   table_alter_post_trigger() RETURNS event_trigger
*   table_alter_pre_trigger() RETURNS event_trigger
*   table_create_post_trigger() RETURNS event_trigger
*   table_drop_post_trigger() RETURNS event_trigger
*   table_drop_pre_trigger() RETURNS event_trigger
*
***********************************************************/

/**********************************************************
* GET DDL FROM CONTEXT
*
* Helper function to parse DDL statement from PG_CONTEXT
* of GET DIAGNOSTICS command
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.get_ddl_from_context(stack TEXT) RETURNS TEXT AS
$$
DECLARE
  ddl_text TEXT;
  objs TEXT[] := '{}';
  do_next BOOLEAN := TRUE;
  ddl_pos INTEGER;
BEGIN
  -- split context by lines
  objs := regexp_split_to_array($1, E'\\r?\\n+');

  -- if context is greater than 1 line, trigger was fired from inside a function
  IF array_length(objs,1) > 1 THEN
    FOR i IN 2..array_length(objs,1) LOOP
      EXIT WHEN do_next = FALSE;
      -- try to find starting position of DDL command
      ddl_pos := GREATEST(
                   position('ALTER TABLE' IN objs[i]),
                   position('DROP TABLE' IN objs[i]),
                   position('DROP SCHEMA' IN objs[i])
                 );
      IF ddl_pos > 0 THEN
        ddl_text := substr(objs[2], ddl_pos, length(objs[2]) - ddl_pos);
        do_next := FALSE;
      END IF;
    END LOOP;
  END IF;

  RETURN ddl_text;
END;
$$
LANGUAGE plpgsql IMMUTABLE STRICT;


/**********************************************************
* flatten_ddl
*
* Helper function for to remove comments and line breaks
* from parsed DDL command
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.flatten_ddl(ddl_command TEXT) RETURNS TEXT AS
$$
SELECT
  string_agg(
    CASE WHEN position('--' in ddl_part) > 0 THEN
      left(ddl_part, position('--' in ddl_part) - 1)
    ELSE
      ddl_part
    END,
    ' '
  )
FROM
  unnest(regexp_split_to_array(
    regexp_replace($1, '/\*(.*?)\*/', '', 'g'),
    E'\\r?\\n'
  )) AS s (ddl_part);
$$
LANGUAGE sql STRICT;


/**********************************************************
* fetch_ident
*
* Helper function to return first word from DDL context
* which could be a schema, table or column name
* (incl. quotes, commas and other special characters)
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.fetch_ident(
  context TEXT,
  fetch_count INTEGER DEFAULT 1
  ) RETURNS TEXT AS
$$
DECLARE
  do_next BOOLEAN := TRUE;
  sql_ident TEXT := '';
  quote_pos INTEGER := 1;
  quote_count INTEGER := 0;
  obj_count INTEGER := 0;
  fetch_result TEXT;
BEGIN
  IF $2 <= 0 THEN
    RAISE EXCEPTION 'Second input must be greather than 0!';
  END IF;

  FOR i IN 1..length($1) LOOP
    EXIT WHEN do_next = FALSE;
    -- parse as long there is no space or within quotes
    IF (substr($1,i,1) <> ' ' AND substr($1,i,1) <> ',' AND substr($1,i,1) <> ';')
       OR (substr(sql_ident,quote_pos,1) = '"' AND (
       (right(sql_ident, 1) = '"') = (quote_pos = length(sql_ident))
      ))
    THEN
      sql_ident := sql_ident || substr($1,i,1);
      IF substr($1,i,1) = '"' THEN
        quote_count := quote_count + 1;
        IF quote_count > 2 THEN
          quote_pos := length(sql_ident);
          quote_count := 1;
        ELSE
          quote_pos := position('"' in sql_ident);
        END IF;
      END IF;
    ELSE
      IF length(sql_ident) > 0 THEN
        obj_count := obj_count + 1;
        IF fetch_result IS NULL THEN
          fetch_result := sql_ident;
        ELSE
          fetch_result := fetch_result || ' ' || sql_ident;
        END IF;
        IF obj_count = $2 THEN
          do_next := FALSE;
        END IF;
        sql_ident := '';
        quote_pos := 1;
        quote_count := 0;
      END IF;
    END IF;
  END LOOP;

  IF length(sql_ident) > 0 THEN
    IF fetch_result IS NULL THEN
      fetch_result := sql_ident;
    ELSE
      fetch_result := fetch_result || ' ' || sql_ident;
    END IF;
  END IF;
  RETURN fetch_result;
END;
$$
LANGUAGE plpgsql STRICT;


/**********************************************************
* GET_TABLE_FROM_QUERY
*
* Helper function to retrieve single schema and table name
* as well as matching log_id from audit_table_log
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.split_table_from_query(
  INOUT query TEXT,
  OUT audit_table_name TEXT,
  OUT audit_schema_name TEXT,
  OUT audit_table_log_id INTEGER,
  OUT audit_id_column_name TEXT,
  OUT audit_old_data BOOLEAN
  ) RETURNS RECORD AS
$$
DECLARE
  fetch_next BOOLEAN := TRUE;
  table_ident TEXT := '';
  ntables INTEGER := 0;
  rec RECORD;
BEGIN
  -- remove comments and line breaks from the DDL string
  query := pgmemento.flatten_ddl(query);

  WHILE fetch_next LOOP
    -- extracting the table identifier from the DDL command
    table_ident := pgmemento.fetch_ident(query);

    -- exit loop when nothing has been fetched
    IF table_ident IS NULL OR length(table_ident) = 0 THEN
      EXIT;
    END IF;

    -- shrink ddl_text by table_ident
    query := substr(query, position(table_ident in query) + length(table_ident), length(query));

    IF position('"' IN table_ident) > 0 OR (
         position('"' IN table_ident) = 0 AND (
           lower(table_ident) NOT IN ('drop', 'table', 'if', 'exists')
         )
       )
    THEN
      BEGIN
        -- if table exists, this should work
        PERFORM table_ident::regclass;
        fetch_next := FALSE;

        EXCEPTION
          WHEN undefined_table THEN
            fetch_next := TRUE;
          WHEN invalid_name THEN
            fetch_next := FALSE;
      END;
    END IF;
  END LOOP;

  -- get table and schema name
  IF table_ident LIKE '%.%' THEN
    -- check if table is audited
    SELECT
      table_name,
      schema_name,
      log_id,
      audit_id_column,
      log_old_data
    INTO
      audit_table_name,
      audit_schema_name,
      audit_table_log_id,
      audit_id_column_name,
      audit_old_data
    FROM
      pgmemento.audit_table_log
    WHERE
      table_name = pgmemento.trim_outer_quotes(split_part(table_ident, '.', 2))
      AND schema_name = pgmemento.trim_outer_quotes(split_part(table_ident, '.', 1))
      AND upper(txid_range) IS NULL
      AND lower(txid_range) IS NOT NULL;

    IF audit_schema_name IS NOT NULL AND audit_table_name IS NOT NULL THEN
      ntables := 1;
    END IF;
  ELSE
    audit_table_name := pgmemento.trim_outer_quotes(table_ident);

    -- check if table is audited and not ambiguous
    FOR rec IN
      SELECT
        schema_name AS schema_name,
        log_id,
        audit_id_column,
        log_old_data
      FROM
        pgmemento.audit_table_log
      WHERE
        table_name = audit_table_name
        AND upper(txid_range) IS NULL
        AND lower(txid_range) IS NOT NULL
    LOOP
      ntables := ntables + 1;
      IF ntables > 1 THEN
        -- table name is found more than once in audit_table_log
        RAISE EXCEPTION 'Please specify the schema name in the DDL command.';
      END IF;
      audit_schema_name := rec.schema_name;
      audit_table_log_id := rec.log_id;
      audit_id_column_name := rec.audit_id_column;
      audit_old_data := rec.log_old_data;
    END LOOP;
  END IF;

  -- table not found in audit_table_log, so it can be changed without logging
  IF ntables IS NULL OR ntables = 0 THEN
    query := NULL;
  END IF;
END;
$$
LANGUAGE plpgsql STRICT;


/**********************************************************
* MODIFY DDL LOGS
*
* Helper function to update tables audit_table_log and
* audit_column_log
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.modify_ddl_log_tables(
  tablename TEXT,
  schemaname TEXT
  ) RETURNS SETOF VOID AS
$$
DECLARE
  tab_id INTEGER;
BEGIN
  -- get id from audit_table_log for given table
  tab_id := pgmemento.register_audit_table($1, $2);

  IF tab_id IS NOT NULL THEN
    -- insert columns that do not exist in audit_column_log table
    INSERT INTO pgmemento.audit_column_log
      (id, audit_table_id, column_name, ordinal_position, data_type, column_default, not_null, txid_range)
    (
      SELECT
        nextval('pgmemento.audit_column_log_id_seq') AS id,
        tab_id AS audit_table_id,
        a.attname AS column_name,
        a.attnum AS ordinal_position,
        substr(
          format_type(a.atttypid, a.atttypmod),
          position('.' IN format_type(a.atttypid, a.atttypmod))+1,
          length(format_type(a.atttypid, a.atttypmod))
        ) AS data_type,
        pg_get_expr(d.adbin, d.adrelid, TRUE) AS column_default,
        a.attnotnull AS not_null,
        numrange(current_setting('pgmemento.t' || txid_current())::numeric, NULL, '(]') AS txid_range
      FROM
        pg_attribute a
      LEFT JOIN
        pg_attrdef d
        ON (a.attrelid, a.attnum) = (d.adrelid, d.adnum)
      LEFT JOIN (
        SELECT
          a.audit_id_column,
          c.ordinal_position,
          c.column_name
        FROM
          pgmemento.audit_table_log a
        JOIN
          pgmemento.audit_column_log c
          ON c.audit_table_id = a.id
        WHERE
          a.id = tab_id
          AND upper(a.txid_range) IS NULL
          AND lower(a.txid_range) IS NOT NULL
          AND upper(c.txid_range) IS NULL
          AND lower(c.txid_range) IS NOT NULL
        ) acl
      ON acl.ordinal_position = a.attnum
      OR acl.audit_id_column = a.attname
      WHERE
        a.attrelid = pgmemento.get_table_oid($1, $2)
        AND a.attnum > 0
        AND NOT a.attisdropped
        AND (acl.ordinal_position IS NULL
         OR (acl.column_name <> a.attname
        AND acl.audit_id_column <> a.attname))
      ORDER BY
        a.attnum
    );

    -- EVENT: Column dropped
    -- update txid_range for removed columns in audit_column_log table
    WITH dropped_columns AS (
      SELECT
        c.id
      FROM
        pgmemento.audit_table_log a
      JOIN
        pgmemento.audit_column_log c
        ON c.audit_table_id = a.id
      LEFT JOIN (
        SELECT
          attname AS column_name,
          $1 AS table_name,
          $2 AS schema_name
        FROM
          pg_attribute
        WHERE
          attrelid = pgmemento.get_table_oid($1, $2)
        ) col
        ON col.column_name = c.column_name
        AND col.table_name = a.table_name
        AND col.schema_name = a.schema_name
      WHERE
        a.id = tab_id
        AND col.column_name IS NULL
        AND upper(a.txid_range) IS NULL
        AND lower(a.txid_range) IS NOT NULL
        AND upper(c.txid_range) IS NULL
        AND lower(c.txid_range) IS NOT NULL
    )
    UPDATE
      pgmemento.audit_column_log acl
    SET
      txid_range = numrange(lower(acl.txid_range), current_setting('pgmemento.t' || txid_current())::numeric, '(]')
    FROM
      dropped_columns dc
    WHERE
      acl.id = dc.id;

    -- EVENT: Column altered
    -- update txid_range for updated columns and insert new versions into audit_column_log table
    WITH updated_columns AS (
      SELECT
        acl.id,
        acl.audit_table_id,
        col.column_name,
        col.ordinal_position,
        col.data_type,
        col.column_default,
        col.not_null
      FROM (
        SELECT
          a.attname AS column_name,
          a.attnum AS ordinal_position,
          substr(
            format_type(a.atttypid, a.atttypmod),
            position('.' IN format_type(a.atttypid, a.atttypmod))+1,
            length(format_type(a.atttypid, a.atttypmod))
          ) AS data_type,
          pg_get_expr(d.adbin, d.adrelid, TRUE) AS column_default,
          a.attnotnull AS not_null,
          $1 AS table_name,
          $2 AS schema_name
        FROM
          pg_attribute a
        LEFT JOIN
          pg_attrdef d
          ON (a.attrelid, a.attnum) = (d.adrelid, d.adnum)
        WHERE
          a.attrelid = pgmemento.get_table_oid($1, $2)
          AND a.attnum > 0
          AND NOT a.attisdropped
      ) col
      JOIN (
        SELECT
          c.*,
          a.table_name,
          a.schema_name
        FROM
          pgmemento.audit_column_log c
        JOIN
          pgmemento.audit_table_log a
          ON a.id = c.audit_table_id
        WHERE
          a.id = tab_id
          AND upper(a.txid_range) IS NULL
          AND lower(a.txid_range) IS NOT NULL
          AND upper(c.txid_range) IS NULL
          AND lower(c.txid_range) IS NOT NULL
        ) acl
        ON col.column_name = acl.column_name
        AND col.table_name = acl.table_name
        AND col.schema_name = acl.schema_name
      WHERE
        col.column_default IS DISTINCT FROM acl.column_default
        OR col.not_null IS DISTINCT FROM acl.not_null
        OR col.data_type IS DISTINCT FROM acl.data_type
    ), insert_new_versions AS (
      INSERT INTO pgmemento.audit_column_log
        (id, audit_table_id, column_name, ordinal_position, data_type, column_default, not_null, txid_range)
      (
        SELECT
          nextval('pgmemento.audit_column_log_id_seq') AS id,
          audit_table_id,
          column_name,
          ordinal_position,
          data_type,
          column_default,
          not_null,
          numrange(current_setting('pgmemento.t' || txid_current())::numeric, NULL, '(]') AS txid_range
        FROM
          updated_columns
      )
    )
    UPDATE
      pgmemento.audit_column_log acl
    SET
      txid_range = numrange(lower(acl.txid_range), current_setting('pgmemento.t' || txid_current())::numeric, '(]')
    FROM
      updated_columns uc
    WHERE
      uc.id = acl.id;
  END IF;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;


/**********************************************************
* MODIFY ROW LOG
*
* Helper function to update row log table for ADD COLUMN
* or ALTER COLUMN events
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.modify_row_log(
  tablename TEXT,
  schemaname TEXT,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text
  ) RETURNS SETOF VOID AS
$$
DECLARE
  added_columns TEXT[] := '{}'::text[];
  altered_columns TEXT[] := '{}'::text[];
BEGIN
  SELECT
    array_agg(c_new.column_name) FILTER (WHERE c_old.column_name IS NULL),
    array_agg(c_new.column_name) FILTER (WHERE c_old.column_name IS NOT NULL)
  INTO
    added_columns,
    altered_columns
  FROM
    pgmemento.audit_column_log c_new
  JOIN
    pgmemento.audit_table_log a
    ON a.id = c_new.audit_table_id
   AND a.table_name = $1
   AND a.schema_name = $2
  LEFT JOIN
    pgmemento.audit_column_log c_old
    ON c_old.column_name = c_new.column_name
   AND c_old.ordinal_position = c_new.ordinal_position
   AND c_old.audit_table_id = a.id
   AND upper(c_old.txid_range) = current_setting('pgmemento.t' || txid_current())::numeric
  WHERE
    lower(c_new.txid_range) = current_setting('pgmemento.t' || txid_current())::numeric
    AND upper(c_new.txid_range) IS NULL;

  IF added_columns IS NOT NULL OR array_length(added_columns, 1) > 0 THEN
    PERFORM pgmemento.log_new_table_state(added_columns, $1, $2,
      concat_ws(';', extract(epoch from transaction_timestamp()), extract(epoch from statement_timestamp()), txid_current(), pgmemento.get_operation_id('ADD COLUMN'), $1, $2),
      $3
    );
  END IF;

  IF altered_columns IS NOT NULL OR array_length(altered_columns, 1) > 0 THEN
    PERFORM pgmemento.log_new_table_state(altered_columns, $1, $2,
      concat_ws(';', extract(epoch from transaction_timestamp()), extract(epoch from statement_timestamp()), txid_current(), pgmemento.get_operation_id('ALTER COLUMN'), $1, $2),
      $3
    );
  END IF;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;


/**********************************************************
* EVENT TRIGGER PROCEDURE schema_drop_pre_trigger
*
* Procedure that is called BEFORE schema will be dropped.
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.schema_drop_pre_trigger() RETURNS event_trigger AS
$$
DECLARE
  ddl_text TEXT := current_query();
  stack TEXT;
  fetch_next BOOLEAN := TRUE;
  schema_ident TEXT;
  rec RECORD;
  table_event_key TEXT;
BEGIN
  -- get context in which trigger has been fired
  GET DIAGNOSTICS stack = PG_CONTEXT;
  stack := pgmemento.get_ddl_from_context(stack);

  -- if DDL command was found in context, trigger was fired from inside a function
  IF stack IS NOT NULL THEN
    -- check if context starts with DROP command
    IF lower(stack) NOT LIKE 'drop%' THEN
      RAISE EXCEPTION 'Could not parse DROP SCHEMA event! SQL context is: %', stack;
    END IF;
    ddl_text := stack;
  END IF;

  -- remove comments and line breaks from the DDL string
  ddl_text := pgmemento.flatten_ddl(ddl_text);

  WHILE fetch_next LOOP
    -- extracting the schema identifier from the DDL command
    schema_ident := pgmemento.fetch_ident(ddl_text);

    -- exit loop when nothing has been fetched
    IF schema_ident IS NULL OR length(schema_ident) = 0 THEN
      EXIT;
    END IF;

    -- shrink ddl_text by schema_ident
    ddl_text := substr(ddl_text, position(schema_ident in ddl_text) + length(schema_ident), length(ddl_text));

    IF position('"' IN schema_ident) > 0 OR (
         position('"' IN schema_ident) = 0 AND (
           lower(schema_ident) NOT IN ('drop', 'schema', 'if', 'exists')
         )
       )
    THEN
      SELECT NOT EXISTS (
        SELECT
          1
        FROM
          pg_namespace
        WHERE
          nspname = pgmemento.trim_outer_quotes(schema_ident)
      )
      INTO
        fetch_next;
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM pgmemento.audit_schema_log
     WHERE schema_name = schema_ident
       AND upper(txid_range) IS NULL
  ) THEN
    -- truncate tables to log the data
    FOR rec IN
      SELECT
        n.nspname AS schemaname,
        c.relname AS tablename,
        a.audit_id_column,
        a.log_old_data
      FROM
        pg_class c
      JOIN
        pg_namespace n
        ON n.oid = c.relnamespace
      JOIN
        pgmemento.audit_table_log a
        ON a.table_name = c.relname
       AND a.schema_name = n.nspname
       AND upper(a.txid_range) IS NULL
       AND lower(a.txid_range) IS NOT NULL
      JOIN
        pgmemento.audit_tables_dependency d
        ON d.schemaname = a.table_name
       AND d.tablename = a.schema_name
      WHERE
        n.nspname = pgmemento.trim_outer_quotes(schema_ident)
      ORDER BY
        n.oid,
        d.depth DESC
    LOOP
      -- log the whole content of the dropped table as truncated
      table_event_key := pgmemento.log_table_event(rec.tablename, rec.schemaname, 'TRUNCATE');
      IF rec.log_old_data THEN
        PERFORM pgmemento.log_old_table_state('{}'::text[], rec.tablename, rec.schemaname, table_event_key, rec.audit_id_column);
      END IF;

      -- now log drop table event
      PERFORM pgmemento.log_table_event(rec.tablename, rec.schemaname, 'DROP TABLE');

      -- unregister table from log tables
      PERFORM pgmemento.unregister_audit_table(rec.tablename, rec.schemaname);
    END LOOP;
  END IF;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* EVENT TRIGGER PROCEDURE table_alter_post_trigger
*
* Procedure that is called AFTER tables have been altered
* e.g. to add, alter or drop columns
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.table_alter_post_trigger() RETURNS event_trigger AS
$$
DECLARE
  obj RECORD;
  tid INTEGER;
  table_log_id INTEGER;
  tg_tablename TEXT;
  tg_schemaname TEXT;
  current_table_name TEXT;
  current_schema_name TEXT;
  current_audit_id_column TEXT;
  current_log_old_data BOOLEAN;
  current_log_new_data BOOLEAN;
  event_op_id SMALLINT;
BEGIN
  tid := current_setting('pgmemento.t' || txid_current())::int;

  FOR obj IN
    SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    -- get table from trigger variable - remove quotes if exists
    tg_tablename := pgmemento.trim_outer_quotes(split_part(obj.object_identity, '.' ,2));
    tg_schemaname := pgmemento.trim_outer_quotes(split_part(obj.object_identity, '.' ,1));

    BEGIN
      -- check if event required to remember log_id from audit_table_log (e.g. RENAME)
      table_log_id := current_setting('pgmemento.' || obj.object_identity)::int;

      -- get old table and schema name for this log_id
      SELECT
        table_name,
        schema_name,
        audit_id_column,
        log_old_data,
        log_new_data
      INTO
        current_table_name,
        current_schema_name,
        current_audit_id_column,
        current_log_old_data,
        current_log_new_data
      FROM
        pgmemento.audit_table_log
      WHERE
        log_id = table_log_id
        AND upper(txid_range) IS NULL
        AND lower(txid_range) IS NOT NULL;

      EXCEPTION
        WHEN others THEN
          NULL; -- no log id set or no open txid_range. Use names from obj.
    END;

    IF current_table_name IS NULL THEN
      current_table_name := tg_tablename;
      current_schema_name := tg_schemaname;

      -- get current settings for audit table
      SELECT
        audit_id_column,
        log_old_data,
        log_new_data
      INTO
        current_audit_id_column,
        current_log_old_data,
        current_log_new_data
      FROM
        pgmemento.audit_table_log
      WHERE
        table_name = current_table_name
        AND schema_name = current_schema_name
        AND upper(txid_range) IS NULL
        AND lower(txid_range) IS NOT NULL;
    ELSE
      -- table got renamed and so remember audit_id_column and logging behavior to register renamed version
      PERFORM set_config('pgmemento.' || tg_schemaname || '.' || tg_tablename || '.audit_id.t' || txid_current(), current_audit_id_column, TRUE);
      PERFORM set_config('pgmemento.' || tg_schemaname || '.' || tg_tablename || '.log_data.t' || txid_current(),
        CASE WHEN current_log_old_data THEN 'old=true,' ELSE 'old=false,' END ||
        CASE WHEN current_log_new_data THEN 'new=true' ELSE 'new=false' END, TRUE);
    END IF;

    -- modify audit_table_log and audit_column_log if DDL events happened
    SELECT
      op_id
    INTO
      event_op_id
    FROM
      pgmemento.table_event_log
    WHERE
      transaction_id = tid
      AND table_name = current_table_name
      AND schema_name = current_schema_name
      AND op_id IN (12, 2, 21, 22, 5, 6);

    IF event_op_id IS NOT NULL THEN
      PERFORM pgmemento.modify_ddl_log_tables(tg_tablename, tg_schemaname);
    END IF;

    -- update row_log to with new log data
    IF current_log_new_data AND (event_op_id = 2 OR event_op_id = 5) THEN
      PERFORM pgmemento.modify_row_log(tg_tablename, tg_schemaname, current_audit_id_column);
    END IF;
  END LOOP;

  EXCEPTION
    WHEN undefined_object THEN
      RETURN; -- no event has been logged, yet
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* EVENT TRIGGER PROCEDURE table_alter_pre_trigger
*
* Procedure that is called BEFORE tables will be altered
* e.g. to log data following an old schema
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.table_alter_pre_trigger() RETURNS event_trigger AS
$$
DECLARE
  ddl_text TEXT := current_query();
  stack TEXT;
  fetch_next BOOLEAN := TRUE;
  table_ident TEXT := '';
  rec RECORD;
  tablename TEXT;
  schemaname TEXT;
  table_log_id INTEGER;
  ntables INTEGER := 0;
  audit_id_columnname TEXT;
  log_old_data BOOLEAN;
  column_candidate TEXT;
  columnname TEXT;
  event_type TEXT;
  column_type TEXT;
  added_columns BOOLEAN := FALSE;
  dropped_columns TEXT[] := '{}'::text[];
  altered_columns TEXT[] := '{}'::text[];
  altered_columns_log TEXT[] := '{}'::text[];
  table_event_key TEXT;
BEGIN
  -- get context in which trigger has been fired
  GET DIAGNOSTICS stack = PG_CONTEXT;
  stack := pgmemento.get_ddl_from_context(stack);

  -- if DDL command was found in context, trigger was fired from inside a function
  IF stack IS NOT NULL THEN
    -- check if context starts with ALTER command
    IF lower(stack) NOT LIKE 'alter%' THEN
      RAISE EXCEPTION 'Could not parse ALTER TABLE event! SQL context is: %', stack;
    END IF;
    ddl_text := stack;
  END IF;

  -- are columns renamed, altered or dropped
  IF lower(ddl_text) LIKE '% type %' OR
     lower(ddl_text) LIKE '% using %' OR
     lower(ddl_text) LIKE '% not null%' OR
     lower(ddl_text) LIKE '%default%' OR
     lower(ddl_text) LIKE '%add column%' OR
     lower(ddl_text) LIKE '%add %' OR
     lower(ddl_text) LIKE '%drop column%' OR
     lower(ddl_text) LIKE '%drop %' OR
     lower(ddl_text) LIKE '%rename %'
  THEN
    -- remove table name from ddl_text
    SELECT
      query,
      audit_table_name,
      audit_schema_name,
      audit_table_log_id,
      audit_id_column_name,
      audit_old_data
    INTO
      ddl_text,
      tablename,
      schemaname,
      table_log_id,
      audit_id_columnname,
      log_old_data
    FROM
      pgmemento.split_table_from_query(ddl_text);

    -- if table is not audited ddl_text will be NULL
    IF ddl_text IS NULL THEN
      RETURN;
    END IF;

    -- check if table got renamed and log event if yes
    IF lower(ddl_text) LIKE ' rename to%' THEN
      PERFORM pgmemento.log_table_event(tablename, schemaname, 'RENAME TABLE');
      -- make sure to quote ident as variable will later be read
      -- from obj trigger variable which can come with quotes
      PERFORM set_config(
        'pgmemento.' || quote_ident(schemaname) || '.' ||
        pgmemento.fetch_ident(substr(ddl_text,11,length(ddl_text))),
        table_log_id::text,
        TRUE
      );
      RETURN;
    END IF;

    -- start parsing columns
    WHILE length(ddl_text) > 0 LOOP
      -- process each single following word in DDL string
      -- hope to find event types, column names and data types
      column_candidate := pgmemento.fetch_ident(ddl_text);

      -- exit loop when nothing has been fetched
      IF column_candidate IS NULL OR length(column_candidate) = 0 THEN
        EXIT;
      END IF;

      -- shrink ddl_text by column_candidate
      ddl_text := substr(ddl_text, position(column_candidate in ddl_text) + length(column_candidate), length(ddl_text));

      -- if keyword 'column' is found, do not reset event type
      IF lower(column_candidate) <> 'column' THEN
        IF event_type IS NOT NULL THEN
          IF event_type = 'ADD' THEN
            -- after ADD we might find a column name
            -- if next word is a data type it must be an ADD COLUMN event
            -- otherwise it could also be an ADD constraint event, which is not audited
            column_type := pgmemento.fetch_ident(ddl_text);
            ddl_text := substr(ddl_text, position(column_type in ddl_text) + length(column_type), length(ddl_text));

            FOR i IN 0..length(ddl_text) LOOP
              EXIT WHEN added_columns = TRUE;
              BEGIN
                IF current_setting('server_version_num')::int < 90600 THEN
                  IF to_regtype((column_type || substr(ddl_text, 1, i))::cstring) IS NOT NULL THEN
                    added_columns := TRUE;
                  END IF;
                ELSE
                  IF to_regtype(column_type || substr(ddl_text, 1, i)) IS NOT NULL THEN
                    added_columns := TRUE;
                  END IF;
                END IF;

                EXCEPTION
                  WHEN syntax_error THEN
                    CONTINUE;
              END;
            END LOOP;
          ELSE
            IF column_candidate = audit_id_columnname THEN
              columnname := column_candidate;
            ELSE
              SELECT
                c.column_name
              INTO
                columnname
              FROM
                pgmemento.audit_column_log c,
                pgmemento.audit_table_log a
              WHERE
                c.audit_table_id = a.id
                AND c.column_name = pgmemento.trim_outer_quotes(column_candidate)
                AND a.table_name = tablename
                AND a.schema_name = schemaname
                AND upper(c.txid_range) IS NULL
                AND lower(c.txid_range) IS NOT NULL;
            END IF;

            IF columnname IS NOT NULL THEN
              CASE event_type
                WHEN 'RENAME' THEN
                  IF column_candidate = audit_id_columnname THEN
                    RAISE EXCEPTION 'Renaming the % column is not possible!', audit_id_columnname;
                  END IF;
                  -- log event as only one RENAME COLUMN action is possible per table per transaction
                  PERFORM pgmemento.log_table_event(tablename, schemaname, 'RENAME COLUMN');
                WHEN 'DROP' THEN
                  dropped_columns := array_append(dropped_columns, columnname);
                WHEN 'ALTER' THEN
                  altered_columns := array_append(altered_columns, columnname);

                  -- check if logging column content is really required
                  column_type := pgmemento.fetch_ident(ddl_text, 6);
                  IF lower(column_type) LIKE '% collate %' OR lower(column_type) LIKE '% using %' THEN
                    altered_columns_log := array_append(altered_columns_log, columnname);
                  END IF;
                ELSE
                  RAISE NOTICE 'Event type % unknown', event_type;
              END CASE;
            END IF;
          END IF;
        END IF;

        -- when event is found column name might be next
        CASE lower(column_candidate)
          WHEN 'add' THEN
            event_type := 'ADD';
          WHEN 'rename' THEN
            event_type := 'RENAME';
          WHEN 'alter' THEN
            event_type := 'ALTER';
          WHEN 'drop' THEN
            event_type := 'DROP';
          ELSE
            event_type := NULL;
        END CASE;
      END IF;
    END LOOP;

    IF added_columns THEN
      -- log ADD COLUMN table event
      table_event_key := pgmemento.log_table_event(tablename, schemaname, 'ADD COLUMN');
    END IF;

    IF array_length(altered_columns, 1) > 0 THEN
      -- log ALTER COLUMN table event
      table_event_key := pgmemento.log_table_event(tablename, schemaname, 'ALTER COLUMN');

      -- log data of entire column(s)
      IF array_length(altered_columns_log, 1) > 0 AND log_old_data THEN
        PERFORM pgmemento.log_old_table_state(altered_columns_log, tablename, schemaname, table_event_key, audit_id_columnname);
      END IF;
    END IF;

    IF array_length(dropped_columns, 1) > 0 THEN
      IF NOT (audit_id_columnname = ANY(dropped_columns)) THEN
        -- log DROP COLUMN table event
        table_event_key := pgmemento.log_table_event(tablename, schemaname, 'DROP COLUMN');

        -- log data of entire column(s)
        IF log_old_data THEN
          PERFORM pgmemento.log_old_table_state(dropped_columns, tablename, schemaname, table_event_key, audit_id_columnname);
        END IF;
      ELSE
        RAISE EXCEPTION 'To remove the % column, please use pgmemento.drop_table_audit!', audit_id_columnname;
      END IF;
    END IF;
  END IF;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* EVENT TRIGGER PROCEDURE table_create_post_trigger
*
* Procedure that is called AFTER new tables have been created
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.table_create_post_trigger() RETURNS event_trigger AS
$$
DECLARE
  obj record;
  tablename TEXT;
  schemaname TEXT;
  current_default_column TEXT;
  current_log_old_data BOOLEAN;
  current_log_new_data BOOLEAN;
BEGIN
  FOR obj IN
    SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF obj.command_tag NOT IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO') OR obj.object_type != 'table' THEN
      CONTINUE;
    END IF;

    -- remove quotes if exists
    tablename := pgmemento.trim_outer_quotes(split_part(obj.object_identity, '.' ,2));
    schemaname := pgmemento.trim_outer_quotes(split_part(obj.object_identity, '.' ,1));

    -- check if auditing is active for schema
    SELECT
      default_audit_id_column,
      default_log_old_data,
      default_log_new_data
    INTO
      current_default_column,
      current_log_old_data,
      current_log_new_data
    FROM
      pgmemento.audit_schema_log
    WHERE
      schema_name = schemaname
      AND upper(txid_range) IS NULL;

    IF current_default_column IS NOT NULL THEN
      -- log as 'create table' event
      PERFORM pgmemento.log_table_event(
        tablename,
        schemaname,
        'CREATE TABLE'
      );

      -- start auditing for new table
      PERFORM pgmemento.create_table_audit(
        tablename,
        schemaname,
        current_default_column,
        current_log_old_data,
        current_log_new_data,
        FALSE
      );
    END IF;
  END LOOP;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* EVENT TRIGGER PROCEDURE table_drop_post_trigger
*
* Procedure that is called AFTER tables have been dropped
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.table_drop_post_trigger() RETURNS event_trigger AS
$$
DECLARE
  obj RECORD;
  tid INTEGER;
  tablename TEXT;
  schemaname TEXT;
BEGIN
  FOR obj IN
    SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type = 'table' AND NOT obj.is_temporary THEN
      BEGIN
        tid := current_setting('pgmemento.t' || txid_current())::int;

        -- remove quotes if exists
        tablename := pgmemento.trim_outer_quotes(split_part(obj.object_identity, '.' ,2));
        schemaname := pgmemento.trim_outer_quotes(split_part(obj.object_identity, '.' ,1));

        -- if DROP AUDIT_ID event exists for table in the current transaction
        -- only create a DROP TABLE event, because auditing has already stopped
        IF EXISTS (
          SELECT
            1
          FROM
            pgmemento.table_event_log
          WHERE
            transaction_id = tid
            AND table_name = tablename
            AND schema_name = schemaname
            AND op_id = 81  -- DROP AUDIT_ID event
        ) THEN
          PERFORM pgmemento.log_table_event(
            tablename,
            schemaname,
            'DROP TABLE'
          );
        ELSE
          -- update txid_range for removed table in audit_table_log table
          PERFORM pgmemento.unregister_audit_table(
            tablename,
            schemaname
          );
        END IF;

        EXCEPTION
          WHEN undefined_object THEN
            RETURN; -- no event has been logged, yet. Thus, table was not audited.
      END;
    END IF;
  END LOOP;
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* EVENT TRIGGER PROCEDURE table_drop_pre_trigger
*
* Procedure that is called BEFORE tables will be dropped.
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.table_drop_pre_trigger() RETURNS event_trigger AS
$$
DECLARE
  ddl_text TEXT := current_query();
  stack TEXT;
  schemaname TEXT;
  tablename TEXT;
  audit_id_columnname TEXT;
  log_old_data BOOLEAN;
  table_event_key TEXT;
BEGIN
  -- get context in which trigger has been fired
  GET DIAGNOSTICS stack = PG_CONTEXT;
  stack := pgmemento.get_ddl_from_context(stack);

  -- if DDL command was found in context, trigger was fired from inside a function
  IF stack IS NOT NULL THEN
    -- check if context starts with DROP command
    IF lower(stack) NOT LIKE 'drop%' THEN
      RAISE EXCEPTION 'Could not parse DROP TABLE event! SQL context is: %', stack;
    END IF;
    ddl_text := stack;
  END IF;

  -- remove table name from ddl_text
  SELECT
    query,
    audit_table_name,
    audit_schema_name,
    audit_id_column_name,
    audit_old_data
  INTO
    ddl_text,
    tablename,
    schemaname,
    audit_id_columnname,
    log_old_data
  FROM
    pgmemento.split_table_from_query(ddl_text);

  -- if table is not audited ddl_text will be NULL
  IF ddl_text IS NULL THEN
    RETURN;
  END IF;

  -- log the whole content of the dropped table as truncated
  table_event_key :=  pgmemento.log_table_event(tablename, schemaname, 'TRUNCATE');
  IF log_old_data THEN
    PERFORM pgmemento.log_old_table_state('{}'::text[], tablename, schemaname, table_event_key, audit_id_columnname);
  END IF;

  -- now log drop table event
  PERFORM pgmemento.log_table_event(tablename, schemaname, 'DROP TABLE');
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* EVENT TRIGGER
*
* Global event triggers that are fired when tables are
* created, altered or dropped
**********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.create_schema_event_trigger(
  trigger_create_table BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF VOID AS
$$
BEGIN
  -- Create event trigger for DROP SCHEMA events to log data
  -- before it is lost
  IF NOT EXISTS (
    SELECT 1 FROM pg_event_trigger
      WHERE evtname = 'pgmemento_schema_drop_pre_trigger'
  ) THEN
    CREATE EVENT TRIGGER pgmemento_schema_drop_pre_trigger ON ddl_command_start
      WHEN TAG IN ('DROP SCHEMA')
        EXECUTE PROCEDURE pgmemento.schema_drop_pre_trigger();
  END IF;

  -- Create event trigger for ALTER TABLE events to update 'audit_column_log' table
  -- after table is altered
  IF NOT EXISTS (
    SELECT 1 FROM pg_event_trigger
      WHERE evtname = 'pgmemento_table_alter_post_trigger'
  ) THEN
    CREATE EVENT TRIGGER pgmemento_table_alter_post_trigger ON ddl_command_end
      WHEN TAG IN ('ALTER TABLE')
        EXECUTE PROCEDURE pgmemento.table_alter_post_trigger();
  END IF;

  -- Create event trigger for ALTER TABLE events to log data
  -- before table is altered
  IF NOT EXISTS (
    SELECT 1 FROM pg_event_trigger
      WHERE evtname = 'pgmemento_table_alter_pre_trigger'
  ) THEN
    CREATE EVENT TRIGGER pgmemento_table_alter_pre_trigger ON ddl_command_start
      WHEN TAG IN ('ALTER TABLE')
        EXECUTE PROCEDURE pgmemento.table_alter_pre_trigger();
  END IF;

  -- Create event trigger for CREATE TABLE events to automatically start auditing on new tables
  -- The user can decide if he wants this behaviour during initializing pgMemento.
  IF $1 THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_event_trigger
        WHERE evtname = 'pgmemento_table_create_post_trigger'
    ) THEN
      CREATE EVENT TRIGGER pgmemento_table_create_post_trigger ON ddl_command_end
        WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
          EXECUTE PROCEDURE pgmemento.table_create_post_trigger();
    END IF;
  END IF;

  -- Create event trigger for DROP TABLE events to update tables 'audit_table_log' and 'audit_column_log'
  -- after table is dropped
  IF NOT EXISTS (
    SELECT 1 FROM pg_event_trigger
      WHERE evtname = 'pgmemento_table_drop_post_trigger'
  ) THEN
    CREATE EVENT TRIGGER pgmemento_table_drop_post_trigger ON sql_drop
      WHEN TAG IN ('DROP TABLE')
        EXECUTE PROCEDURE pgmemento.table_drop_post_trigger();
  END IF;

  -- Create event trigger for DROP TABLE events to log data
  -- before it is lost
  IF NOT EXISTS (
    SELECT 1 FROM pg_event_trigger
      WHERE evtname = 'pgmemento_table_drop_pre_trigger'
  ) THEN
    CREATE EVENT TRIGGER pgmemento_table_drop_pre_trigger ON ddl_command_start
      WHEN TAG IN ('DROP TABLE')
        EXECUTE PROCEDURE pgmemento.table_drop_pre_trigger();
  END IF;
END;
$$
LANGUAGE plpgsql STRICT;

CREATE OR REPLACE FUNCTION pgmemento.drop_schema_event_trigger() RETURNS SETOF VOID AS
$$
  DROP EVENT TRIGGER IF EXISTS pgmemento_schema_drop_pre_trigger;
  DROP EVENT TRIGGER IF EXISTS pgmemento_table_alter_post_trigger;
  DROP EVENT TRIGGER IF EXISTS pgmemento_table_alter_pre_trigger;
  DROP EVENT TRIGGER IF EXISTS pgmemento_table_create_post_trigger;
  DROP EVENT TRIGGER IF EXISTS pgmemento_table_drop_post_trigger;
  DROP EVENT TRIGGER IF EXISTS pgmemento_table_drop_pre_trigger;
$$
LANGUAGE sql;




-- RESTORE.sql
--
-- Author:      Felix Kunde <felix-kunde@gmx.de>
--
--              This skript is free software under the LGPL Version 3
--              See the GNU Lesser General Public License at
--              http://www.gnu.org/copyleft/lgpl.html
--              for more details.
-------------------------------------------------------------------------------
-- About:
-- This script provides functions to restore previous data states, be a single
-- value, a record, a table or a whole database schema
-------------------------------------------------------------------------------
--
-- ChangeLog:
--
-- Version | Date       | Description                                       | Author
-- 0.7.9     2021-03-28   fix getting column list                             FKun
-- 0.7.8     2021-03-24   fix restoring NULL instead of recent version        FKun
-- 0.7.7     2021-03-21   fix jsonb_populate_value for array values           FKun
-- 0.7.6     2020-07-28   fix restore for JSONB and array values              FKun
-- 0.7.5     2020-04-13   fix NULL check in restore_record function           FKun
-- 0.7.4     2020-03-23   reflect dynamic audit_id in logged tables           FKun
-- 0.7.3     2020-02-29   reflect new schema of row_log table                 FKun
-- 0.7.2     2020-02-09   reflect changes on schema and triggers              FKun
-- 0.7.1     2020-02-08   stop using trim_outer_quotes for tables             FKun
-- 0.7.0     2019-03-23   reflect schema changes in UDFs                      FKun
-- 0.6.9     2019-03-09   enable restoring as MATERIALIZED VIEWs              FKun
-- 0.6.8     2019-02-25   restore_record with setof return for emtpy result   FKun
-- 0.6.7     2018-11-04   have two restore_record_definition functions        FKun
-- 0.6.6     2018-11-02   consider schema changes when restoring versions     FKun
-- 0.6.5     2018-10-28   renamed file to RESTORE.sql                         FKun
--                        extended API to return multiple versions per row
-- 0.6.4     2018-10-25   renamed generate functions to restore_record/set    FKun
--                        which do not return JSONB anymore
--                        new template helper restore_record_definition
--                        use BOOLEAN type instead of INTEGER (0,1)
-- 0.6.3     2018-10-24   restoring tables now works without templates        FKun
--                        moved audit_table_check to LOG_UTIL
-- 0.6.2     2018-10-23   rewritten restore_query to return relational        FKun
--                        instead of JSONB
-- 0.6.1     2018-09-22   new functions to retrieve the value of a single     FKun
--                        columns from the logs
-- 0.6.0     2018-07-16   reflect changes in transaction_id handling          FKun
-- 0.5.1     2017-07-26   reflect changes of updated logging behaviour        FKun
-- 0.5.0     2017-07-12   reflect changes to audit_column_log table           FKun
-- 0.4.4     2017-04-07   split up restore code to different functions        FKun
-- 0.4.3     2017-04-05   greatly improved performance for restoring          FKun
--                        using window functions with a FILTER
-- 0.4.2     2017-03-28   better logic to query tables if nothing found       FKun
--                        in logs (considers also rename events)
-- 0.4.1     2017-03-15   reflecting new DDL log table schema                 FKun
-- 0.4.0     2017-03-05   updated JSONB functions                             FKun
-- 0.3.0     2016-04-14   a new template mechanism for restoring              FKun
-- 0.2.2     2016-03-08   minor change to generate_log_entry function         FKun
-- 0.2.1     2016-02-14   removed unnecessary plpgsql and dynamic sql code    FKun
-- 0.2.0     2015-05-26   more efficient queries                              FKun
-- 0.1.0     2014-11-26   initial commit                                      FKun
--

/**********************************************************
* C-o-n-t-e-n-t:
*
* FUNCTIONS:
*   create_restore_template(until_tid INTEGER, template_name TEXT, table_name TEXT, schema_name TEXT DEFAULT 'public'::text,
*     preserve_template BOOLEAN DEFAULT FALSE) RETURNS SETOF VOID
*   jsonb_populate_value(jsonb_log JSONB, column_name TEXT, INOUT template anyelement) RETURNS anyelement
*   restore_change(during_tid INTEGER, aid BIGINT, column_name TEXT, INOUT restored_value anyelement) RETURNS anyelement
*   restore_query(start_from_tid INTEGER, end_at_tid INTEGER, table_name TEXT, schema_name TEXT DEFAULT 'public'::text,
*     aid BIGINT DEFAULT NULL, all_versions BOOLEAN DEFAULT FALSE) RETURNS TEXT
*   restore_record(start_from_tid INTEGER, end_at_tid INTEGER, table_name TEXT, schema_name TEXT, aid BIGINT,
*     jsonb_output BOOLEAN DEFAULT FALSE) RETURNS SETOF RECORD
*   restore_records(start_from_tid INTEGER, end_at_tid INTEGER, table_name TEXT, schema_name TEXT, aid BIGINT,
*     jsonb_output BOOLEAN DEFAULT FALSE) RETURNS SETOF RECORD
*   restore_record_definition(start_from_tid INTEGER, end_at_tid INTEGER, table_log_id INTEGER,
*     audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text) RETURNS TEXT
*   restore_record_definition(tid INTEGER, table_name TEXT, schema_name TEXT DEFAULT 'public'::text,
*     audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text) RETURNS TEXT
*   restore_recordset(start_from_tid INTEGER, end_at_tid INTEGER, table_name TEXT, schema_name TEXT DEFAULT 'public'::text,
*     jsonb_output BOOLEAN DEFAULT FALSE) RETURNS SETOF RECORD
*   restore_recordsets(start_from_tid INTEGER, end_at_tid INTEGER, table_name TEXT, schema_name TEXT DEFAULT 'public'::text,
*     jsonb_output BOOLEAN DEFAULT FALSE) RETURNS SETOF RECORD
*   restore_schema_state(start_from_tid INTEGER, end_at_tid INTEGER, original_schema_name TEXT, target_schema_name TEXT,
*     target_table_type TEXT DEFAULT 'VIEW', update_state BOOLEAN DEFAULT FALSE) RETURNS SETOF VOID
*   restore_table_state(start_from_tid INTEGER, end_at_tid INTEGER, original_table_name TEXT, original_schema_name TEXT,
*     target_schema_name TEXT, target_table_type TEXT DEFAULT 'VIEW', update_state BOOLEAN DEFAULT FALSE) RETURNS SETOF VOID
*   restore_value(until_tid INTEGER, aid BIGINT, column_name TEXT, INOUT restored_value anyelement) RETURNS anyelement
***********************************************************/


/**********************************************************
* RESTORE VALUE
*
* Returns the historic value before a given transaction_id
* and given audit_id with the correct data type.
* - jsonb_populate_value is used for casting
* - restore_value returns the historic column value <= tid
* - restore_change returns the historic column value in case
*   it was changed during given tid (NULL otherwise)
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.jsonb_populate_value(
  jsonb_log JSONB,
  column_name TEXT,
  INOUT template anyelement
  ) RETURNS anyelement AS
$$
BEGIN
  IF $1 IS NOT NULL THEN
    IF right(pg_typeof($3)::text, 2) = '[]' THEN
      EXECUTE format('SELECT translate($1->>$2, ''[]'', ''{}'')::%s', pg_typeof($3))
        INTO template USING $1, $2;
    ELSE
      EXECUTE format('SELECT ($1->>$2)::%s', pg_typeof($3))
        INTO template USING $1, $2;
    END IF;
  ELSE
    EXECUTE format('SELECT NULL::%s', pg_typeof($3))
      INTO template;
  END IF;
END;
$$
LANGUAGE plpgsql STABLE;


CREATE OR REPLACE FUNCTION pgmemento.restore_value(
  until_tid INTEGER,
  aid BIGINT,
  column_name TEXT,
  INOUT restored_value anyelement
  ) RETURNS anyelement AS
$$
SELECT
  pgmemento.jsonb_populate_value(r.old_data, $3, $4) AS restored_value
FROM
  pgmemento.row_log r
JOIN
  pgmemento.table_event_log e
  ON r.event_key = e.event_key
WHERE
  r.audit_id = $2
  AND r.old_data ? $3
  AND e.transaction_id <= $1
ORDER BY
  e.id DESC
LIMIT 1;
$$
LANGUAGE sql STABLE;


CREATE OR REPLACE FUNCTION pgmemento.restore_change(
  during_tid INTEGER,
  aid BIGINT,
  column_name TEXT,
  INOUT restored_value anyelement
  ) RETURNS anyelement AS
$$
SELECT
  pgmemento.jsonb_populate_value(r.old_data, $3, $4) AS restored_value
FROM
  pgmemento.row_log r
JOIN
  pgmemento.table_event_log e
  ON r.event_key = e.event_key
WHERE
  r.audit_id = $2
  AND e.transaction_id = $1
ORDER BY
  e.id DESC
LIMIT 1;
$$
LANGUAGE sql STABLE;


/**********************************************************
* RESTORE QUERY
*
* Helper function to produce query string for restore
* single or multiple log entries (depends if aid is given)
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.restore_query(
  start_from_tid INTEGER,
  end_at_tid INTEGER,
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  aid BIGINT DEFAULT NULL,
  all_versions BOOLEAN DEFAULT FALSE
  ) RETURNS TEXT AS
$$
DECLARE
  log_id INTEGER;
  tab_name TEXT;
  tab_schema TEXT;
  tab_audit_id_column TEXT;
  tab_id INTEGER;
  new_tab_name TEXT;
  new_tab_schema TEXT;
  new_audit_id_column TEXT;
  new_tab_id INTEGER;
  join_recent_state BOOLEAN := FALSE;
  extract_logs TEXT;
  find_logs TEXT;
  query_text TEXT := E'SELECT\n';
BEGIN
  -- first check if table can be restored
  SELECT
    table_log_id,
    log_tab_name,
    log_tab_schema,
    log_audit_id_column,
    log_tab_id,
    recent_tab_name,
    recent_tab_schema,
    recent_audit_id_column,
    recent_tab_id
  INTO
    log_id,
    tab_name,
    tab_schema,
    tab_audit_id_column,
    tab_id,
    new_tab_name,
    new_tab_schema,
    new_audit_id_column,
    new_tab_id
  FROM
    pgmemento.audit_table_check($2, $3, $4);

  IF tab_id IS NULL THEN
    RAISE EXCEPTION 'Can not restore table ''%'' because it did not exist before requested transaction %', $3, $2;
  END IF;

  -- check if recent state can be queried
  IF new_tab_id IS NULL THEN
    new_tab_id := tab_id;
  ELSE
    join_recent_state := TRUE;
  END IF;

  -- loop over all columns and query the historic value for each column separately
  SELECT
    string_agg(
       format(E'  CASE WHEN jsonb_typeof(g.log_%s) = ''null'' THEN NULL::%s\n', c_old.column_name, c_old.data_type)
    || CASE WHEN join_recent_state AND c_new.column_name IS NOT NULL
       THEN format(E'       WHEN g.log_%s IS NULL THEN x.%I\n', c_old.column_name, c_new.column_name) ELSE '' END
    || '       ELSE '
    || CASE WHEN right(c_old.data_type, 2) = '[]'
       THEN 'translate(' ELSE '' END
    || format('(jsonb_build_object(%L, g.log_%s) ->> %L)', c_old.column_name,
       quote_ident(c_old.column_name || CASE WHEN c_old.column_count > 1 THEN '_' || c_old.column_count ELSE '' END), c_old.column_name)
    || CASE WHEN right(c_old.data_type, 2) = '[]'
       THEN ',''[]'',''{}'')' ELSE '' END
    || format(E'::%s\n', c_old.data_type)
    || format('  END AS %s', quote_ident(c_old.column_name || CASE WHEN c_old.column_count > 1 THEN '_' || c_old.column_count ELSE '' END))
      , E',\n' ORDER BY c_old.ordinal_position, c_old.column_count
    ),
    string_agg(
      CASE WHEN $6
      THEN format(E'    CASE WHEN transaction_id >= %L AND transaction_id < %L\n    THEN ',
        CASE WHEN lower(c_old.txid_range) IS NOT NULL
        THEN lower(c_old.txid_range)
        ELSE $1 END,
        CASE WHEN upper(c_old.txid_range) IS NOT NULL
        THEN upper(c_old.txid_range)
        ELSE $2 END)
      ELSE '    ' END
    || format('first_value(a.old_data -> %L) OVER ', c_old.column_name, c_old.column_name)
    || format('(PARTITION BY f.event_key, a.audit_id ORDER BY a.old_data -> %L IS NULL, a.id)', c_old.column_name)
    || CASE WHEN $6
       THEN format(E'\n    ELSE jsonb_build_object(%L, NULL) -> %L END', c_old.column_name, c_old.column_name)
       ELSE '' END
    || format(' AS log_%s', quote_ident(c_old.column_name || CASE WHEN c_old.column_count > 1 THEN '_' || c_old.column_count ELSE '' END))
        , E',\n' ORDER BY c_old.ordinal_position, c_old.column_count
    )
  INTO
    extract_logs,
    find_logs
  FROM
    pgmemento.get_column_list($1, $2, log_id, tab_name, tab_schema, $6) c_old
  LEFT JOIN
    pgmemento.audit_column_log c_new
    ON c_old.ordinal_position = c_new.ordinal_position
   AND c_new.audit_table_id = new_tab_id
   AND upper(c_new.txid_range) IS NULL
   AND lower(c_new.txid_range) IS NOT NULL;

  -- finish restore query
  query_text := query_text
    -- add part to extract values from logs or get recent state
    || extract_logs
    || format(E',\n  g.audit_id AS %s', quote_ident(tab_audit_id_column))
    || CASE WHEN $6 THEN E',\n  g.stmt_time,\n  g.table_operation,\n  g.transaction_id\n' ELSE E'\n' END
    -- use DISTINCT ON to get only one row
    || E'FROM (\n  SELECT DISTINCT ON ('
    || CASE WHEN $6 THEN 'f.event_key, ' ELSE '' END
    || E'f.audit_id)\n'
    -- add subquery g that finds the right JSONB log snippets for each column
    || find_logs
    || format(E',\n    f.audit_id')
    || CASE WHEN $6 THEN E',\n    f.stmt_time,\n    f.table_operation,\n    f.transaction_id\n' ELSE E'\n' END
    -- add subquery f to get last event for given audit_id before given transaction
    || E'  FROM (\n'
    || '    SELECT '
    || CASE WHEN $6 THEN E'\n' ELSE E'DISTINCT ON (r.audit_id)\n' END
    || '      r.audit_id, e.event_key, e.op_id'
    || CASE WHEN $6 THEN E', e.stmt_time, e.table_operation, e.transaction_id\n' ELSE E'\n' END
    || E'    FROM\n'
    || E'      pgmemento.row_log r\n'
    || E'    JOIN\n'
    || E'      pgmemento.table_event_log e ON r.event_key = e.event_key\n'
    || format(E'    WHERE e.transaction_id >= %L AND e.transaction_id < %L\n', $1, $2)
    || CASE WHEN $5 IS NULL THEN
         format(E'      AND e.table_name = %L AND e.schema_name = %L\n', tab_name, tab_schema)
       ELSE
         format(E'      AND r.audit_id = %L\n', $5)
       END
    || E'    ORDER BY\n'
    || E'      r.audit_id, e.id DESC\n'
    || E'  ) f\n'
    -- left join on row_log table and consider only events younger than the one extracted in subquery f
    || E'  LEFT JOIN\n'
    || E'    pgmemento.row_log a ON a.audit_id = f.audit_id AND a.event_key > f.event_key\n'
    -- if 'all_versions' flag is FALSE do not produce a result if row did not exist before second transaction ID
    -- therefore, filter out DELETE, TRUNCATE or DROP TABLE events
    || CASE WHEN $6 THEN '' ELSE E'  WHERE\n    f.op_id < 7\n' END
    -- order by oldest log entry for given audit_id
    || E'  ORDER BY\n'
    || CASE WHEN $6 THEN '    f.event_key, ' ELSE '    ' END
    || 'f.audit_id'
    || E'\n) g\n'
    -- left join on actual table to get the recent value for a field if nothing is found in the logs
    || CASE WHEN join_recent_state THEN
         E'LEFT JOIN\n'
         || format(E'  %I.%I x ON x.' || new_audit_id_column || E' = g.audit_id\n', new_tab_schema, new_tab_name)
       ELSE
         ''
       END;

  RETURN query_text;
END;
$$
LANGUAGE plpgsql STABLE;


/**********************************************************
* RESTORE RECORD/SET
*
* Functions to reproduce historic tuples for a given
* transaction range. To see all different versions of the
* tuples and not just the version at 'end_at_tid' set
* the all_versions flag to TRUE.
* Retrieving the correct result requires you to provide a
* column definition list. If you prefer to retrieve the
* logs as JSONB, set the last flag to TRUE. Then the column
* definition list requires just one JSONB column which is
* easier to write.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.restore_record(
  start_from_tid INTEGER,
  end_at_tid INTEGER,
  table_name TEXT,
  schema_name TEXT,
  aid BIGINT,
  jsonb_output BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF RECORD AS
$$
DECLARE
  -- init query string
  restore_query_text TEXT := pgmemento.restore_query($1, $2, $3, $4, $5);
BEGIN
  IF $6 IS TRUE THEN
    restore_query_text := E'SELECT to_jsonb(t) FROM (\n' || restore_query_text || E'\n) t';
  END IF;

  -- execute the SQL command
  RETURN QUERY EXECUTE restore_query_text;
END;
$$
LANGUAGE plpgsql STABLE STRICT;

CREATE OR REPLACE FUNCTION pgmemento.restore_records(
  start_from_tid INTEGER,
  end_at_tid INTEGER,
  table_name TEXT,
  schema_name TEXT,
  aid BIGINT,
  jsonb_output BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF RECORD AS
$$
DECLARE
  -- init query string
  restore_query_text TEXT := pgmemento.restore_query($1, $2, $3, $4, $5, TRUE);
BEGIN
  IF $6 IS TRUE THEN
    restore_query_text := E'SELECT to_jsonb(t) FROM (\n' || restore_query_text || E'\n) t';
  END IF;

  -- execute the SQL command
  RETURN QUERY EXECUTE restore_query_text;
END;
$$
LANGUAGE plpgsql STABLE STRICT;

CREATE OR REPLACE FUNCTION pgmemento.restore_recordset(
  start_from_tid INTEGER,
  end_at_tid INTEGER,
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  jsonb_output BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF RECORD AS
$$
DECLARE
  -- init query string
  restore_query_text TEXT := pgmemento.restore_query($1, $2, $3, $4);
BEGIN
  IF $5 IS TRUE THEN
    restore_query_text := E'SELECT to_jsonb(t) FROM (\n' || restore_query_text || E'\n) t';
  END IF;

  -- execute the SQL command
  RETURN QUERY EXECUTE restore_query_text;
END;
$$
LANGUAGE plpgsql STABLE STRICT;

CREATE OR REPLACE FUNCTION pgmemento.restore_recordsets(
  start_from_tid INTEGER,
  end_at_tid INTEGER,
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  jsonb_output BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF RECORD AS
$$
DECLARE
  -- init query string
  restore_query_text TEXT := pgmemento.restore_query($1, $2, $3, $4, NULL, TRUE);
BEGIN
  IF $5 IS TRUE THEN
    restore_query_text := E'SELECT to_jsonb(t) FROM (\n' || restore_query_text || E'\n) t';
  END IF;

  -- execute the SQL command
  RETURN QUERY EXECUTE restore_query_text;
END;
$$
LANGUAGE plpgsql STABLE STRICT;


/**********************************************************
* RESTORE RECORD DEFINITION
*
* Functions that return a column definition list for
* retrieving historic tuples with functions restor_record(s)
* and restore_recordset(s). Simply attach the output to your
* restore query. When restoring multiple versions of one
* row that set the flag include events to TRUE
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.restore_record_definition(
  tid INTEGER,
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text
  ) RETURNS TEXT AS
$$
SELECT
  'AS (' ||
  string_agg(
    quote_ident(column_name) || ' ' || data_type,
    ', ' ORDER BY ordinal_position
  )
  || format(', %s bigint)', quote_ident($4))
FROM
  pgmemento.get_column_list_by_txid($1, $2, $3);
$$
LANGUAGE sql STABLE STRICT;

CREATE OR REPLACE FUNCTION pgmemento.restore_record_definition(
  start_from_tid INTEGER,
  end_at_tid INTEGER,
  table_log_id INTEGER,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text
  ) RETURNS TEXT AS
$$
SELECT
  'AS (' ||
  string_agg(
    quote_ident(column_name || CASE WHEN column_count > 1 THEN '_' || column_count ELSE '' END)
    || ' ' || data_type
  , ', ' ORDER BY ordinal_position, column_count
  )
  || format(', %s bigint', quote_ident($4))
  || ', stmt_time timestamp with time zone, table_operation text, transaction_id integer)'
FROM
  pgmemento.get_column_list_by_txid_range($1, $2, $3);
$$
LANGUAGE sql STABLE STRICT;


/**********************************************************
* CREATE RESTORE TEMPLATE
*
* Function to create a temporary table to be used as a
* historically correct template for restoring data with
* jsonb_populate_record function
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.create_restore_template(
  until_tid INTEGER,
  template_name TEXT,
  table_name TEXT,
  schema_name TEXT DEFAULT 'public'::text,
  preserve_template BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF VOID AS
$$
DECLARE
  stmt TEXT;
  audit_id_column_name TEXT;
BEGIN
  -- get columns that exist before transaction with id end_at_tid
  SELECT
    string_agg(
      quote_ident(c.column_name)
      || ' '
      || c.data_type
      || CASE WHEN c.column_default IS NOT NULL AND c.column_default NOT LIKE '%::regclass%'
         THEN ' DEFAULT ' || c.column_default ELSE '' END
      || CASE WHEN c.not_null THEN ' NOT NULL' ELSE '' END,
      ', ' ORDER BY c.ordinal_position
    ),
    (array_agg(DISTINCT t.audit_id_column))[1]
  INTO
    stmt,
    audit_id_column_name
  FROM
    pgmemento.audit_column_log c
  JOIN
    pgmemento.audit_table_log t
    ON t.id = c.audit_table_id
  WHERE
    t.table_name = $3
    AND t.schema_name = $4
    AND t.txid_range @> $1::numeric
    AND c.txid_range @> $1::numeric;

  -- create temp table
  IF stmt IS NOT NULL THEN
    EXECUTE format(
      'CREATE TEMPORARY TABLE IF NOT EXISTS %I ('
         || stmt
         || format(', %s bigint ', quote_ident(audit_id_column_name))
         || 'DEFAULT nextval(''pgmemento.audit_id_seq''::regclass) unique not null'
         || ') '
         || CASE WHEN $5 THEN 'ON COMMIT PRESERVE ROWS' ELSE 'ON COMMIT DROP' END, $2);
  END IF;
END;
$$
LANGUAGE plpgsql STRICT;


/**********************************************************
* RESTORE TABLE STATE
*
* See what the table looked like at a given date.
* The table state will be restored in a separate schema.
* The user can choose if it will appear as a TABLE, VIEW
* or MATERIALIZED VIEW
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.restore_table_state(
  start_from_tid INTEGER,
  end_at_tid INTEGER,
  original_table_name TEXT,
  original_schema_name TEXT,
  target_schema_name TEXT,
  target_table_type TEXT DEFAULT 'VIEW',
  update_state BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF VOID AS
$$
DECLARE
  existing_table_type CHAR(1);
  replace_view TEXT := ' ';
  restore_query TEXT;
BEGIN
  -- test if target schema already exists
  IF NOT EXISTS (
    SELECT
      1
    FROM
      pg_namespace
    WHERE
      nspname = $5
  ) THEN
    EXECUTE format('CREATE SCHEMA %I', $5);
  END IF;

  -- test if table, view or materialized view already exists in target schema
  SELECT
    c.relkind
  INTO
    existing_table_type
  FROM
    pg_class c,
    pg_namespace n
  WHERE
    c.relnamespace = n.oid
    AND c.relname = $3
    AND n.nspname = $5
    AND (
      c.relkind = 'r'
      OR c.relkind = 'v'
      OR c.relkind = 'm'
    );

  IF existing_table_type IS NOT NULL THEN
    IF $7 THEN
      -- drop or replace existing objects
      IF existing_table_type = 'r' THEN
        PERFORM pgmemento.drop_table_state($3, $5);
      ELSIF existing_table_type = 'm' THEN
        EXECUTE format('DROP MATERIALIZED VIEW %I.%I CASCADE', $5, $3);
      ELSE
        IF $6 = 'MATERIALIZED VIEW' OR $6 = 'TABLE' THEN
          EXECUTE format('DROP VIEW %I.%I CASCADE', $5, $3);
        ELSE
          replace_view := ' OR REPLACE ';
        END IF;
      END IF;
    ELSE
      RAISE EXCEPTION
        'Relation ''%'' in schema ''%'' does already exists. Either set the update_state flag to TRUE or choose another target schema.',
        $3, $5;
    END IF;
  END IF;

  -- let's go back in time - restore a table state for given transaction interval
  IF upper($6) = 'VIEW' OR upper($6) = 'MATERIALIZED VIEW' OR upper($6) = 'TABLE' THEN
    restore_query := 'CREATE'
      || replace_view || $6
      || format(E' %I.%I AS\n', $5, $3)
      || pgmemento.restore_query($1, $2, $3, $4);

    -- finally execute query string
    EXECUTE restore_query;
  ELSE
    RAISE NOTICE 'Table type ''%'' not supported. Use ''VIEW'', ''MATERIALIZED VIEW'' or ''TABLE''.', $6;
  END IF;
END;
$$
LANGUAGE plpgsql STRICT;

-- perform restore_table_state on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.restore_schema_state(
  start_from_tid INTEGER,
  end_at_tid INTEGER,
  original_schema_name TEXT,
  target_schema_name TEXT,
  target_table_type TEXT DEFAULT 'VIEW',
  update_state BOOLEAN DEFAULT FALSE
  ) RETURNS SETOF VOID AS
$$
SELECT
  pgmemento.restore_table_state($1, $2, table_name, schema_name, $4, $5, $6)
FROM
  pgmemento.audit_table_log
WHERE
  schema_name = $3
  AND txid_range @> $2::numeric;
$$
LANGUAGE sql STRICT;




-- REVERT.sql
--
-- Author:      Felix Kunde <felix-kunde@gmx.de>
--
--              This skript is free software under the LGPL Version 3
--              See the GNU Lesser General Public License at
--              http://www.gnu.org/copyleft/lgpl.html
--              for more details.
-------------------------------------------------------------------------------
-- About:
-- This script provides functions to revert single transactions and entire database
-- states.
--
-------------------------------------------------------------------------------
--
-- ChangeLog:
--
-- Version | Date       | Description                                   | Author
-- 0.7.9     2021-12-23   session variables starting with letter          ol-teuto
-- 0.7.8     2021-03-21   fix revert for array columns                    FKun
-- 0.7.7     2020-04-20   add revert for DROP AUDIT_ID event              FKun
-- 0.7.6     2020-04-19   add revert for REINIT TABLE event               FKun 
-- 0.7.5     2020-04-13   remove txid from log_table_event                FKun
-- 0.7.4     2020-03-23   reflect configurable audit_id column            FKun
-- 0.7.3     2020-02-29   reflect new schema of row_log table             FKun
-- 0.7.2     2020-01-09   reflect changes on schema and triggers          FKun
-- 0.7.1     2019-04-21   reuse log_id when reverting DROP TABLE events   FKun
-- 0.7.0     2019-03-23   reflect schema changes in UDFs                  FKun
-- 0.6.4     2019-02-14   Changed revert ADD AUDIT_ID events              FKun
-- 0.6.3     2018-11-20   revert updates with composite data types        FKun
-- 0.6.2     2018-09-24   improved reverts when column type is altered    FKun
-- 0.6.1     2018-07-24   support for RENAME events & improved queries    FKun
-- 0.6.0     2018-07-16   reflect changes in transaction_id handling      FKun
-- 0.5.1     2017-08-08   sort reverts by row_log ID and not audit_id     FKun
--                        improved revert_distinct_transaction(s)
-- 0.5.0     2017-07-25   add revert support for DDL events               FKun
-- 0.4.1     2017-04-11   improved revert_distinct_transaction(s)         FKun
-- 0.4.0     2017-03-08   integrated table dependencies                   FKun
--                        recover_audit_version takes txid as first arg
-- 0.3.0     2016-04-29   splitting up the functions to match the new     FKun
--                        logging behavior for table events
-- 0.2.2     2016-03-08   added another revert procedure                  FKun
-- 0.2.1     2016-02-14   removed dynamic sql code                        FKun
-- 0.2.0     2015-02-26   added revert_transaction procedure              FKun
-- 0.1.0     2014-11-26   initial commit                                  FKun
--

/**********************************************************
* C-o-n-t-e-n-t:
*
* FUNCTIONS:
*   recover_audit_version(tid INTEGER, aid BIGINT, changes JSONB, table_op INTEGER,
*     table_name TEXT, schema_name TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text) RETURNS SETOF VOID
*   revert_distinct_transaction(tid INTEGER) RETURNS SETOF VOID
*   revert_distinct_transactions(start_from_tid INTEGER, end_at_tid INTEGER) RETURNS SETOF VOID
*   revert_transaction(tid INTEGER) RETURNS SETOF VOID
*   revert_transactions(start_from_tid INTEGER, end_at_tid INTEGER) RETURNS SETOF VOID
***********************************************************/

/**********************************************************
* RECOVER
*
* Procedure to apply DML operations recovered from the logs
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.recover_audit_version(
  tid INTEGER,
  aid BIGINT,
  changes JSONB,
  table_op INTEGER,
  tab_name TEXT,
  tab_schema TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text
  ) RETURNS SETOF VOID AS
$$
DECLARE
  except_tables TEXT[] DEFAULT '{}';
  stmt TEXT;
  table_log_id INTEGER;
  current_transaction INTEGER;
BEGIN
  CASE
  -- CREATE TABLE case
  WHEN $4 = 1 THEN
    -- try to drop table
    BEGIN
      EXECUTE format('DROP TABLE %I.%I', $6, $5);

      EXCEPTION
        WHEN undefined_table THEN
          RAISE NOTICE 'Could not revert CREATE TABLE event for table %.%: %', $6, $5, SQLERRM;
    END;

  -- REINIT TABLE case
  WHEN $4 = 11 THEN
    BEGIN
      -- reinit only given table and exclude all others
      SELECT
        array_agg(table_name)
      INTO
        except_tables
      FROM
        pgmemento.audit_table_log
      WHERE
        table_name <> $5
        AND schema_name = $6
        AND upper(txid_range) = $1;

      PERFORM
        pgmemento.reinit($6, audit_id_column, log_old_data, log_new_data, FALSE, except_tables)
      FROM
        pgmemento.audit_table_log
      WHERE
        table_name = $5
        AND schema_name = $6
        AND upper(txid_range) = $1;

      -- if auditing was stopped within the same transaction (e.g. reverted ADD AUDIT_ID event)
      -- the REINIT TABLE event will not be logged by reinit function
      -- therefore, we have to make the insert here
      IF NOT EXISTS (
        SELECT
          1
        FROM
          pgmemento.table_event_log
        WHERE
          transaction_id = current_setting('pgmemento.t' || txid_current())::int
          AND table_name = $5
          AND schema_name = $6
          AND op_id = 11  -- REINIT TABLE event
      ) THEN
        PERFORM pgmemento.log_table_event($5, $6, 'REINIT TABLE');
      END IF;

      EXCEPTION
        WHEN others THEN
          RAISE NOTICE 'Could not revert REINIT TABLE event for table %.%: %', $6, $5, SQLERRM;
    END;

  -- RENAME TABLE case
  WHEN $4 = 12 THEN
    BEGIN
      -- collect information of renamed table
      SELECT
        format('%I.%I',
          t_old.schema_name,
          t_old.table_name
        )
      INTO
        stmt
      FROM
        pgmemento.audit_table_log t_old,
        pgmemento.audit_table_log t_new
      WHERE
        t_old.log_id = t_new.log_id
        AND t_new.table_name = $5
        AND t_new.schema_name = $6
        AND upper(t_new.txid_range) = $1
        AND lower(t_old.txid_range) = $1;

      -- try to re-rename table
      IF stmt IS NOT NULL THEN
        EXECUTE 'ALTER TABLE ' || stmt || format(' RENAME TO %I', $5);
      END IF;

      EXCEPTION
        WHEN undefined_table THEN
          RAISE NOTICE 'Could not revert RENAME TABLE event for table %: %', stmt, SQLERRM;
    END;

  -- ADD COLUMN case
  WHEN $4 = 2 THEN
    BEGIN
      -- collect added columns
      SELECT
        string_agg(
          'DROP COLUMN '
          || quote_ident(c.column_name),
          ', ' ORDER BY c.id DESC
        ) INTO stmt
      FROM
        pgmemento.audit_column_log c
      JOIN
        pgmemento.audit_table_log t
        ON c.audit_table_id = t.id
      WHERE
        lower(c.txid_range) = $1
        AND t.table_name = $5
        AND t.schema_name = $6;

      -- try to execute ALTER TABLE command
      IF stmt IS NOT NULL THEN
        EXECUTE format('ALTER TABLE %I.%I ' || stmt , $6, $5);
      END IF;

      EXCEPTION
        WHEN others THEN
          RAISE NOTICE 'Could not revert ADD COLUMN event for table %.%: %', $6, $5, SQLERRM;
    END;

  -- ADD AUDIT_ID case
  WHEN $4 = 21 THEN
    PERFORM pgmemento.drop_table_audit($5, $6, $7, TRUE, FALSE);

  -- RENAME COLUMN case
  WHEN $4 = 22 THEN
    BEGIN
      -- collect information of renamed table
      SELECT
        'RENAME COLUMN ' || quote_ident(c_old.column_name) ||
        ' TO ' || quote_ident(c_new.column_name)
      INTO
        stmt
      FROM
        pgmemento.audit_table_log t,
        pgmemento.audit_column_log c_old,
        pgmemento.audit_column_log c_new
      WHERE
        c_old.audit_table_id = t.id
        AND c_new.audit_table_id = t.id
        AND t.table_name = $5
        AND t.schema_name = $6
        AND t.txid_range @> $1::numeric
        AND c_old.ordinal_position = c_new.ordinal_position
        AND upper(c_new.txid_range) = $1
        AND lower(c_old.txid_range) = $1;

      -- try to re-rename table
      IF stmt IS NOT NULL THEN
        EXECUTE format('ALTER TABLE %I.%I ' || stmt, $6, $5);
      END IF;

      EXCEPTION
        WHEN undefined_table THEN
          RAISE NOTICE 'Could not revert RENAME COLUMN event for table %.%: %', $6, $5, SQLERRM;
    END;

  -- INSERT case
  WHEN $4 = 3 THEN
    -- aid can be null in case of conflicts during insert
    IF $2 IS NOT NULL THEN
      -- delete inserted row
      BEGIN
        EXECUTE format(
          'DELETE FROM %I.%I WHERE %I = $1',
          $6, $5, $7)
          USING $2;

        -- row is already deleted
        EXCEPTION
          WHEN no_data_found THEN
            NULL;
      END;
    END IF;

  -- UPDATE case
  WHEN $4 = 4 THEN
    -- update the row with values from changes
    IF $2 IS NOT NULL AND $3 <> '{}'::jsonb THEN
      BEGIN
        -- create SET part
        SELECT
          string_agg(set_columns,', ')
        INTO
          stmt
        FROM (
          SELECT
            CASE WHEN jsonb_typeof(j.value) = 'object' AND p.typname IS NOT NULL THEN
              pgmemento.jsonb_unroll_for_update(j.key, j.value, p.typname)
            ELSE
              quote_ident(j.key) || '=' ||
              CASE WHEN jsonb_typeof(j.value) = 'array' THEN
                quote_nullable(translate($3 ->> j.key, '[]', '{}'))
              ELSE
                quote_nullable($3 ->> j.key)
              END
            END AS set_columns
          FROM
            jsonb_each($3) j
          LEFT JOIN
            pgmemento.audit_column_log c
            ON c.column_name = j.key
           AND jsonb_typeof(j.value) = 'object'
           AND upper(c.txid_range) IS NULL
           AND lower(c.txid_range) IS NOT NULL
          LEFT JOIN
            pgmemento.audit_table_log t
            ON t.id = c.audit_table_id
           AND t.table_name = $5
           AND t.schema_name = $6
          LEFT JOIN
            pg_type p
            ON p.typname = c.data_type
           AND p.typcategory = 'C'
        ) u;

        -- try to execute UPDATE command
        EXECUTE format(
          'UPDATE %I.%I t SET ' || stmt || ' WHERE t.%I = $1',
          $6, $5, $7)
          USING $2;

        -- row is already deleted
        EXCEPTION
          WHEN others THEN
            RAISE NOTICE 'Could not revert UPDATE event for table %.%: %', $6, $5, SQLERRM;
      END;
    END IF;

  -- ALTER COLUMN case
  WHEN $4 = 5 THEN
    BEGIN
      -- collect information of altered columns
      SELECT
        string_agg(
          format('ALTER COLUMN %I SET DATA TYPE %s USING pgmemento.restore_change(%L, %I, %L, NULL::%s)',
            c_new.column_name, c_old.data_type, $1, $7, quote_ident(c_old.column_name), c_old.data_type),
          ', ' ORDER BY c_new.id
        ) INTO stmt
      FROM
        pgmemento.audit_table_log t,
        pgmemento.audit_column_log c_old,
        pgmemento.audit_column_log c_new
      WHERE
        c_old.audit_table_id = t.id
        AND c_new.audit_table_id = t.id
        AND t.table_name = $5
        AND t.schema_name = $6
        AND t.txid_range @> $1::numeric
        AND upper(c_old.txid_range) = $1
        AND lower(c_new.txid_range) = $1
        AND c_old.ordinal_position = c_new.ordinal_position
        AND c_old.data_type <> c_new.data_type;

      -- alter table if it has not been done, yet
      IF stmt IS NOT NULL THEN
        EXECUTE format('ALTER TABLE %I.%I ' || stmt , $6, $5);
      END IF;

      -- it did not work for some reason
      EXCEPTION
        WHEN others THEN
          RAISE NOTICE 'Could not revert ALTER COLUMN event for table %.%: %', $6, $5, SQLERRM;
    END;

  -- DROP COLUMN case
  WHEN $4 = 6 THEN
    BEGIN
      -- collect information of dropped columns
      SELECT
        string_agg(
          'ADD COLUMN '
          || quote_ident(c_old.column_name)
          || ' '
          || CASE WHEN c_old.column_default LIKE 'nextval(%'
                   AND pgmemento.trim_outer_quotes(c_old.column_default) LIKE E'%_seq\'::regclass)' THEN
               CASE WHEN c_old.data_type = 'smallint' THEN 'smallserial'
                    WHEN c_old.data_type = 'integer' THEN 'serial'
                    WHEN c_old.data_type = 'bigint' THEN 'bigserial'
                    ELSE c_old.data_type END
             ELSE
               c_old.data_type
               || CASE WHEN c_old.column_default IS NOT NULL
                  THEN ' DEFAULT ' || c_old.column_default ELSE '' END
             END
          || CASE WHEN c_old.not_null THEN ' NOT NULL' ELSE '' END,
          ', ' ORDER BY c_old.id
        ) INTO stmt
      FROM
        pgmemento.audit_table_log t
      JOIN
        pgmemento.audit_column_log c_old
        ON c_old.audit_table_id = t.id
      LEFT JOIN LATERAL (
        SELECT
          c.column_name
        FROM
          pgmemento.audit_table_log atl
        JOIN
          pgmemento.audit_column_log c
          ON c.audit_table_id = atl.id
        WHERE
          atl.table_name = t.table_name
          AND atl.schema_name = t.schema_name
          AND upper(c.txid_range) IS NULL
          AND lower(c.txid_range) IS NOT NULL
        ) c_new
        ON c_old.column_name = c_new.column_name
      WHERE
        upper(c_old.txid_range) = $1
        AND c_new.column_name IS NULL
        AND t.table_name = $5
        AND t.schema_name = $6;

      -- try to execute ALTER TABLE command
      IF stmt IS NOT NULL THEN
        EXECUTE format('ALTER TABLE %I.%I ' || stmt , $6, $5);
      END IF;

      -- fill in data with an UPDATE statement if audit_id is set
      IF $2 IS NOT NULL THEN
        PERFORM pgmemento.recover_audit_version($1, $2, $3, 4, $5, $6, $7);
      END IF;

      EXCEPTION
        WHEN duplicate_column THEN
          -- if column already exists just do an UPDATE
          PERFORM pgmemento.recover_audit_version($1, $2, $3, 4, $5, $6, $7);
	END;

  -- DELETE or TRUNCATE case
  WHEN $4 = 7 OR $4 = 8 THEN
    IF $2 IS NOT NULL THEN
      BEGIN
        EXECUTE format(
          'INSERT INTO %I.%I SELECT * FROM jsonb_populate_record(null::%I.%I, $1)',
          $6, $5, $6, $5)
          USING $3;

        -- row has already been re-inserted, so update it based on the values of this deleted version
        EXCEPTION
          WHEN unique_violation THEN
            -- merge changes with recent version of table record and update row
            PERFORM pgmemento.recover_audit_version($1, $2, $3, 4, $5, $6, $7);
      END;
    END IF;

  -- DROP AUDIT_ID case
  WHEN $4 = 81 THEN
    -- first check if a preceding CREATE TABLE event already recreated the audit_id
    BEGIN
      current_transaction := current_setting('pgmemento.t' || txid_current())::int;

      EXCEPTION
        WHEN undefined_object THEN
          NULL;
    END;

    BEGIN
      IF current_transaction IS NULL OR NOT EXISTS (
        SELECT
          1
        FROM
          pgmemento.table_event_log
        WHERE
          transaction_id = current_transaction
          AND table_name = $5
          AND schema_name = $6
          AND op_id = 1  -- RE/CREATE TABLE event
      ) THEN
        -- try to restart auditing for table
        PERFORM
          pgmemento.create_table_audit(table_name, schema_name, audit_id_column, log_old_data, log_new_data, FALSE)
        FROM
          pgmemento.audit_table_log
        WHERE
          table_name = $5
          AND schema_name = $6
          AND upper(txid_range) = $1;
      END IF;
      
      -- audit_id already exists
      EXCEPTION
        WHEN others THEN
          RAISE NOTICE 'Could not revert DROP AUDIT_ID event for table %.%: %', $6, $5, SQLERRM;
    END;

  -- DROP TABLE case
  WHEN $4 = 9 THEN
    -- collect information of columns of dropped table
    SELECT
      t.log_id,
      string_agg(
        quote_ident(c_old.column_name)
        || ' '
        || CASE WHEN c_old.column_default LIKE 'nextval(%'
                 AND pgmemento.trim_outer_quotes(c_old.column_default) LIKE E'%_seq\'::regclass)' THEN
             CASE WHEN c_old.data_type = 'smallint' THEN 'smallserial'
                  WHEN c_old.data_type = 'integer' THEN 'serial'
                  WHEN c_old.data_type = 'bigint' THEN 'bigserial'
                  ELSE c_old.data_type END
           ELSE
             c_old.data_type
             || CASE WHEN c_old.column_default IS NOT NULL
                THEN ' DEFAULT ' || c_old.column_default ELSE '' END
           END
        || CASE WHEN c_old.not_null THEN ' NOT NULL' ELSE '' END,
        ', ' ORDER BY c_old.ordinal_position
      )
    INTO
      table_log_id,
      stmt
    FROM
      pgmemento.audit_table_log t
    JOIN
      pgmemento.audit_column_log c_old
      ON c_old.audit_table_id = t.id
    LEFT JOIN LATERAL (
      SELECT
        atl.table_name
      FROM
        pgmemento.audit_table_log atl
      WHERE
        atl.table_name = t.table_name
        AND atl.schema_name = t.schema_name
        AND upper(atl.txid_range) IS NULL
        AND lower(atl.txid_range) IS NOT NULL
      ) t_new
      ON t.table_name = t_new.table_name
    WHERE
      upper(c_old.txid_range) = $1
      AND c_old.column_name <> $7
      AND t_new.table_name IS NULL
      AND t.table_name = $5
      AND t.schema_name = $6
    GROUP BY
      t.log_id;

    -- try to create table
    IF stmt IS NOT NULL THEN
      PERFORM pgmemento.log_table_event($5, $6, 'RECREATE TABLE');
      PERFORM set_config('pgmemento.' || $6 || '.' || $5, table_log_id::text, TRUE);
      EXECUTE format('CREATE TABLE IF NOT EXISTS %I.%I (' || stmt || ')', $6, $5);
    END IF;

    -- fill in truncated data with an INSERT statement if audit_id is set
    IF $2 IS NOT NULL THEN
      PERFORM pgmemento.recover_audit_version($1, $2, $3, 8, $5, $6, $7);
    END IF;

  END CASE;
END;
$$
LANGUAGE plpgsql;


/**********************************************************
* REVERT TRANSACTION
*
* Procedures to revert a single transaction or a range of
* transactions. All table operations are processed in
* order of table dependencies so no foreign keys should be
* violated.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.revert_transaction(tid INTEGER) RETURNS SETOF VOID AS
$$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT
      t.id,
      r.audit_id,
      r.old_data,
      e.op_id,
      a.table_name,
      a.schema_name,
      a.audit_id_column,
      rank() OVER (PARTITION BY r.event_key ORDER BY r.id DESC) AS audit_order,
      CASE WHEN e.op_id > 4 THEN
        rank() OVER (ORDER BY d.depth ASC)
      ELSE
        rank() OVER (ORDER BY d.depth DESC)
      END AS dependency_order
    FROM
      pgmemento.transaction_log t
    JOIN
      pgmemento.table_event_log e
      ON e.transaction_id = t.id
    JOIN
      pgmemento.audit_table_log a
      ON a.table_name = e.table_name
     AND a.schema_name = e.schema_name
     AND ((a.txid_range @> t.id::numeric AND NOT e.op_id IN (1, 11, 21))
      OR (lower(a.txid_range) = t.id::numeric AND NOT e.op_id IN (81, 9)))
    LEFT JOIN
      pgmemento.audit_tables_dependency d
      ON d.table_log_id = a.log_id
    LEFT JOIN
      pgmemento.row_log r
      ON r.event_key = e.event_key
     AND e.op_id <> 5
    WHERE
      t.id = $1
    ORDER BY
      dependency_order,
      e.id DESC,
      audit_order
  LOOP
    PERFORM pgmemento.recover_audit_version(rec.id, rec.audit_id, rec.old_data, rec.op_id, rec.table_name, rec.schema_name, rec.audit_id_column);
  END LOOP;
END;
$$
LANGUAGE plpgsql STRICT;

CREATE OR REPLACE FUNCTION pgmemento.revert_transactions(
  start_from_tid INTEGER,
  end_at_tid INTEGER
  ) RETURNS SETOF VOID AS
$$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT
      t.id,
      r.audit_id,
      r.old_data,
      e.op_id,
      a.table_name,
      a.schema_name,
      a.audit_id_column,
      rank() OVER (PARTITION BY t.id, r.event_key ORDER BY r.id DESC) AS audit_order,
      CASE WHEN e.op_id > 4 THEN
        rank() OVER (ORDER BY d.depth ASC)
      ELSE
        rank() OVER (ORDER BY d.depth DESC)
      END AS dependency_order
    FROM
      pgmemento.transaction_log t
    JOIN
      pgmemento.table_event_log e
      ON e.transaction_id = t.id
    JOIN
      pgmemento.audit_table_log a
      ON a.table_name = e.table_name
     AND a.schema_name = e.schema_name
     AND ((a.txid_range @> t.id::numeric AND NOT e.op_id IN (1, 11, 21))
      OR (lower(a.txid_range) = t.id::numeric AND NOT e.op_id IN (81, 9)))
    LEFT JOIN
      pgmemento.audit_tables_dependency d
      ON d.table_log_id = a.log_id
    LEFT JOIN
      pgmemento.row_log r
      ON r.event_key = e.event_key
     AND e.op_id <> 5
    WHERE
      t.id BETWEEN $1 AND $2
    ORDER BY
      t.id DESC,
      dependency_order,
      e.id DESC,
      audit_order
  LOOP
    PERFORM pgmemento.recover_audit_version(rec.id, rec.audit_id, rec.old_data, rec.op_id, rec.table_name, rec.schema_name, rec.audit_id_column);
  END LOOP;
END;
$$
LANGUAGE plpgsql STRICT;


/**********************************************************
* REVERT DISTINCT TRANSACTION
*
* Procedures to revert a single transaction or a range of
* transactions. For each distinct audit_id only the oldest
* operation is applied to make the revert process faster.
* This can be a fallback method for revert_transaction if
* foreign key violations are occurring.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.revert_distinct_transaction(tid INTEGER) RETURNS SETOF VOID AS
$$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT
      q.tid,
      q.audit_id,
      CASE WHEN e2.op_id > 6 THEN e2.op_id ELSE e1.op_id END AS op_id,
      q.old_data,
      a.table_name,
      a.schema_name,
      a.audit_id_column,
      rank() OVER (PARTITION BY e1.id ORDER BY q.row_log_id DESC) AS audit_order,
      CASE WHEN e1.op_id > 4 THEN
        rank() OVER (ORDER BY d.depth ASC)
      ELSE
        rank() OVER (ORDER BY d.depth DESC)
      END AS dependency_order
    FROM (
      SELECT
        audit_id,
        table_name,
        schema_name,
        transaction_id AS tid,
        min(event_id) AS first_event,
        max(event_id) AS last_event,
        min(id) AS row_log_id,
        pgmemento.jsonb_merge(old_data ORDER BY id DESC) AS old_data
      FROM (
        SELECT
          r.id,
          r.audit_id,
          r.old_data,
          e.id AS event_id,
          e.table_name,
          e.schema_name,
          e.transaction_id,
          CASE WHEN r.audit_id IS NULL THEN e.id ELSE NULL END AS ddl_event
        FROM
          pgmemento.table_event_log e
        LEFT JOIN
          pgmemento.row_log r
          ON r.event_key = e.event_key
         AND e.op_id <> 5
        WHERE
          e.transaction_id = $1
      ) s
      GROUP BY
        audit_id,
        table_name,
        schema_name,
        ddl_event,
        transaction_id
    ) q
    JOIN
      pgmemento.table_event_log e1
      ON e1.id = q.first_event
    JOIN
      pgmemento.table_event_log e2
      ON e2.id = q.last_event
    JOIN
      pgmemento.audit_table_log a
      ON a.table_name = q.table_name
     AND a.schema_name = q.schema_name
     AND (a.txid_range @> q.tid::numeric
      OR lower(a.txid_range) = q.tid::numeric)
    LEFT JOIN pgmemento.audit_tables_dependency d
      ON d.table_log_id = a.log_id
    WHERE
      NOT (
        e1.op_id = 1
        AND e2.op_id = 9
      )
      AND NOT (
        e1.op_id = 21
        AND e2.op_id = 81
      )
      AND NOT (
        e1.op_id = 3
        AND (e2.op_id BETWEEN 7 AND 9)
      )
    ORDER BY
      dependency_order,
      e1.id DESC,
      audit_order
  LOOP
    PERFORM pgmemento.recover_audit_version(rec.tid, rec.audit_id, rec.old_data, rec.op_id, rec.table_name, rec.schema_name, rec.audit_id_column);
  END LOOP;
END;
$$
LANGUAGE plpgsql STRICT;

CREATE OR REPLACE FUNCTION pgmemento.revert_distinct_transactions(
  start_from_tid INTEGER,
  end_at_tid INTEGER
  ) RETURNS SETOF VOID AS
$$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT
      q.tid,
      q.audit_id,
      CASE WHEN e2.op_id > 6 THEN e2.op_id ELSE e1.op_id END AS op_id,
      q.old_data,
      a.table_name,
      a.schema_name,
      a.audit_id_column,
      rank() OVER (PARTITION BY e1.id ORDER BY q.row_log_id DESC) AS audit_order,
      CASE WHEN e1.op_id > 4 THEN
        rank() OVER (ORDER BY d.depth ASC)
      ELSE
        rank() OVER (ORDER BY d.depth DESC)
      END AS dependency_order
    FROM (
      SELECT
        audit_id,
        table_name,
        schema_name,
        min(transaction_id) AS tid,
        min(event_id) AS first_event,
        max(event_id) AS last_event,
        min(id) AS row_log_id,
        pgmemento.jsonb_merge(old_data ORDER BY id DESC) AS old_data
      FROM (
        SELECT
          r.id,
          r.audit_id,
          r.old_data,
          e.id AS event_id,
          e.table_name,
          e.schema_name,
          e.transaction_id,
          CASE WHEN r.audit_id IS NULL THEN e.id ELSE NULL END AS ddl_event
        FROM
          pgmemento.table_event_log e
        LEFT JOIN
          pgmemento.row_log r
          ON r.event_key = e.event_key
         AND e.op_id <> 5
        WHERE
          e.transaction_id BETWEEN $1 AND $2
      ) s
      GROUP BY
        audit_id,
        table_name,
        schema_name,
        ddl_event
    ) q
    JOIN
      pgmemento.table_event_log e1
      ON e1.id = q.first_event
    JOIN
      pgmemento.table_event_log e2
      ON e2.id = q.last_event
    JOIN
      pgmemento.audit_table_log a
      ON a.table_name = q.table_name
     AND a.schema_name = q.schema_name
     AND (a.txid_range @> q.tid::numeric
      OR lower(a.txid_range) = q.tid::numeric)
    LEFT JOIN pgmemento.audit_tables_dependency d
      ON d.table_log_id = a.log_id
    WHERE
      NOT (
        e1.op_id = 1
        AND e2.op_id = 9
      )
      AND NOT (
        e1.op_id = 21
        AND e2.op_id = 81
      )
      AND NOT (
        e1.op_id = 3
        AND (e2.op_id BETWEEN 7 AND 9)
      )
    ORDER BY
      q.tid DESC,
      dependency_order,
      e1.id DESC,
      audit_order
  LOOP
    PERFORM pgmemento.recover_audit_version(rec.tid, rec.audit_id, rec.old_data, rec.op_id, rec.table_name, rec.schema_name, rec.audit_id_column);
  END LOOP;
END;
$$
LANGUAGE plpgsql STRICT;




-- SCHEMA_MANAGEMENT.sql
--
-- Author:      Felix Kunde <felix-kunde@gmx.de>
--
--              This skript is free software under the LGPL Version 3
--              See the GNU Lesser General Public License at
--              http://www.gnu.org/copyleft/lgpl.html
--              for more details.
-------------------------------------------------------------------------------
-- About:
-- If pgMemento has been used to restore tables as BASE TABLEs they do not include
-- PRIMARY KEYs, FOREIGN KEYs, INDEXes, SEQUENCEs and DEFAULT values for columns.
-- This script provides procedures to add those elements by querying information
-- on recent contraints (as such metadata is yet not logged by pgMemento).
-- Moreover, recreated tables can be moved or copied to another schema or they
-- can just be dropped. This could be useful when choosing a restored state as to
-- be the new production state.
-------------------------------------------------------------------------------
--
-- ChangeLog:
--
-- Version | Date       | Description                                   | Author
-- 0.6.0     2020-04-03   reflect dynamic audit_id in logged tables       FKun
-- 0.5.0     2020-03-07   set SECURITY DEFINER in all functions           FKun
-- 0.4.1     2020-02-08   use get_table_oid instead of trimming quotes    FKun
-- 0.4.0     2019-02-14   support for quoted tables and schemas           FKun
-- 0.4.0     2018-10-25   copy_data argument changed to boolean           FKun
-- 0.3.0     2017-07-27   avoid querying the information_schema           FKun
--                        removed default_values_* functions
-- 0.2.1     2016-02-14   removed unnecessary plpgsql code                FKun
-- 0.2.0     2015-06-06   added procedures and renamed file               FKun
-- 0.1.0     2014-11-26   initial commit as INDEX_SCHEMA.sql              FKun
--

/**********************************************************
* C-o-n-t-e-n-t:
*
* FUNCTIONS:
*   drop_schema_state(table_name TEXT, target_schema_name TEXT DEFAULT 'public'::text) RETURNS SETOF VOID
*   drop_table_state(table_name TEXT, target_schema_name TEXT DEFAULT 'public'::text) RETURNS SETOF VOID
*   fkey_schema_state(target_schema_name TEXT, original_schema_name TEXT DEFAULT 'public'::text,
*     except_tables TEXT[] DEFAULT '{}') RETURNS SETOF VOID
*   fkey_table_state(table_name TEXT, target_schema_name TEXT, original_schema_name TEXT DEFAULT 'public'::text)
*     RETURNS SETOF VOID
*   index_schema_state(target_schema_name TEXT, original_schema_name TEXT DEFAULT 'public'::text,
*     except_tables TEXT[] DEFAULT '{}') RETURNS SETOF VOID
*   index_table_state(table_name TEXT, target_schema_name TEXT, original_schema_name TEXT DEFAULT 'public'::text)
*     RETURNS SETOF VOID
*   move_schema_state(target_schema_name TEXT, source_schema_name TEXT DEFAULT 'public'::text, except_tables TEXT[] DEFAULT '{}',
*     copy_data INTEGER DEFAULT 1) RETURNS SETOF void AS
*   move_table_state(table_name TEXT, target_schema_name TEXT, source_schema_name TEXT, copy_data BOOLEAN DEFAULT TRUE
*     RETURNS SETOF VOID
*   pkey_schema_state(target_schema_name TEXT, original_schema_name TEXT DEFAULT 'public'::text,
*     except_tables TEXT[] DEFAULT '{}') RETURNS SETOF VOID
*   pkey_table_state(target_table_name TEXT, target_schema_name TEXT, original_schema_name TEXT DEFAULT 'public'::text)
*     RETURNS SETOF VOID
*   sequence_schema_state(target_schema_name TEXT, original_schema_name TEXT DEFAULT 'public'::text)
*     RETURNS SETOF VOID
***********************************************************/

/**********************************************************
* PKEY TABLE STATE
*
* If a table state is produced as a base table it will not have
* a primary key. The primary key might be reconstructed by
* querying the recent primary key of the table. If no primary
* can be redefined the audit_id column will be used.
***********************************************************/
-- define a primary key for a produced table
CREATE OR REPLACE FUNCTION pgmemento.pkey_table_state(
  target_table_name TEXT,
  target_schema_name TEXT,
  original_schema_name TEXT DEFAULT 'public'::text
  ) RETURNS SETOF VOID AS
$$
DECLARE
  pkey_columns TEXT := '';
  audit_id_column_name TEXT;
BEGIN
  -- rebuild primary key columns to index produced tables
  SELECT
    string_agg(quote_ident(pga.attname),', ')
  INTO
    pkey_columns
  FROM
    pg_index pgi,
    pg_class pgc,
    pg_attribute pga
  WHERE
    pgc.oid = pgmemento.get_table_oid($1, $3)
    AND pgi.indrelid = pgc.oid
    AND pga.attrelid = pgc.oid
    AND pga.attnum = ANY(pgi.indkey)
    AND pgi.indisprimary;

  IF pkey_columns IS NULL THEN
    SELECT
      audit_id_column
    INTO
      audit_id_column_name
    FROM
      pgmemento.audit_table_log
    WHERE
      table_name = $1
      AND schema_name = $2;

    RAISE NOTICE 'Table ''%'' has no primary key defined. Column ''%'' will be used as primary key.', $1, audit_id_column_name;
    pkey_columns := audit_id_column_name;
  END IF;

  EXECUTE format('ALTER TABLE %I.%I ADD PRIMARY KEY (' || pkey_columns || ')', $2, $1);
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform pkey_table_state on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.pkey_schema_state(
  target_schema_name TEXT,
  original_schema_name TEXT DEFAULT 'public'::text,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS SETOF VOID AS
$$
SELECT
  pgmemento.pkey_table_state(c.relname, $1, $2)
FROM
  pg_class c,
  pg_namespace n
WHERE
  c.relnamespace = n.oid
  AND n.nspname = $2
  AND c.relkind = 'r'
  AND c.relname <> ALL (COALESCE($3,'{}'::text[]));
$$
LANGUAGE sql
SECURITY DEFINER;


/**********************************************************
* FKEY TABLE STATE
*
* If multiple table states are produced as tables they are not
* referenced which each other. Foreign key relations might be
* reconstructed by querying the recent foreign keys of the table.
***********************************************************/
-- define foreign keys between produced tables
CREATE OR REPLACE FUNCTION pgmemento.fkey_table_state(
  table_name TEXT,
  target_schema_name TEXT,
  original_schema_name TEXT DEFAULT 'public'::text
  ) RETURNS SETOF VOID AS
$$
DECLARE
  fkey RECORD;
BEGIN
  -- rebuild foreign key constraints
  FOR fkey IN
    SELECT
      c.conname AS fkey_name,
      a.attname AS fkey_column,
      t.relname AS ref_table,
      a_ref.attname AS ref_column,
      CASE c.confupdtype
        WHEN 'a' THEN 'no action'
        WHEN 'r' THEN 'restrict'
        WHEN 'c' THEN 'cascade'
        WHEN 'n' THEN 'set null'
        WHEN 'd' THEN 'set default'
	  END AS on_up,
      CASE c.confdeltype
        WHEN 'a' THEN 'no action'
        WHEN 'r' THEN 'restrict'
        WHEN 'c' THEN 'cascade'
        WHEN 'n' THEN 'set null'
        WHEN 'd' THEN 'set default'
	  END AS on_del,
      CASE c.confmatchtype
        WHEN 'f' THEN 'full'
        WHEN 'p' THEN 'partial'
        WHEN 'u' THEN 'simple'
      END AS mat
    FROM
      pg_constraint c
    JOIN
      pg_attribute a
      ON a.attrelid = c.conrelid
      AND a.attnum = ANY (c.conkey)
    JOIN
      pg_attribute a_ref
      ON a_ref.attrelid = c.confrelid
      AND a_ref.attnum = ANY (c.confkey)
    JOIN
      pg_class t
      ON t.oid = a_ref.attrelid
    WHERE
      c.conrelid = pgmemento.get_table_oid($1, $3)
      AND c.contype = 'f'
  LOOP
    BEGIN
      -- test query
      EXECUTE format(
        'SELECT 1 FROM %I.%I a, %I.%I b WHERE a.%I = b.%I LIMIT 1',
        $2, $1, $2, fkey.ref_table, fkey.fkey_column, fkey.ref_column);

      -- recreate foreign key of original table
      EXECUTE format(
        'ALTER TABLE %I.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES %I.%I ON UPDATE %I ON DELETE %I MATCH %I',
        $2, $1, fkey.fkey_name, fkey.fkey_column, $2, fkey.ref_table, fkey.ref_column, fkey.on_up, fkey.on_del, fkey.mat);

      EXCEPTION
        WHEN OTHERS THEN
          RAISE NOTICE 'Could not recreate foreign key constraint ''%'' on table ''%'': %', fkey.fkey_name, $1, SQLERRM;
          NULL;
    END;
  END LOOP;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform fkey_table_state on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.fkey_schema_state(
  target_schema_name TEXT,
  original_schema_name TEXT DEFAULT 'public'::text,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS SETOF VOID AS
$$
SELECT
  pgmemento.fkey_table_state(c.relname, $1, $2)
FROM
  pg_class c,
  pg_namespace n
WHERE
  c.relnamespace = n.oid
  AND n.nspname = $2
  AND c.relkind = 'r'
  AND c.relname <> ALL (COALESCE($3,'{}'::text[]));
$$
LANGUAGE sql
SECURITY DEFINER;


/**********************************************************
* INDEX TABLE STATE
*
* If a produced table shall be used for queries indexes will
* be necessary in order to guarantee high performance. Indexes
* might be reconstructed by querying recent indexes of the table.
***********************************************************/
-- define index(es) on columns of a produced table
CREATE OR REPLACE FUNCTION pgmemento.index_table_state(
  table_name TEXT,
  target_schema_name TEXT,
  original_schema_name TEXT DEFAULT 'public'::text
  ) RETURNS SETOF VOID AS
$$
DECLARE
  stmt TEXT;
BEGIN
  -- rebuild user defined indexes
  FOR stmt IN
    SELECT
      replace(pg_get_indexdef(c.oid),' ON ', format(' ON %I.', $2))
    FROM
      pg_index i
    JOIN
      pg_class c
      ON c.oid = i.indexrelid
    WHERE
      i.indrelid = pgmemento.get_table_oid($1, $3)
      AND i.indisprimary = 'f'
  LOOP
    BEGIN
      EXECUTE stmt;

      EXCEPTION
        WHEN OTHERS THEN
          RAISE NOTICE 'Could not recreate index ''%'' on table ''%'': %', idx.idx_name, $1, SQLERRM;
    END;
  END LOOP;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform index_table_state on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.index_schema_state(
  target_schema_name TEXT,
  original_schema_name TEXT DEFAULT 'public'::text,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS SETOF VOID AS
$$
SELECT
  pgmemento.index_table_state(c.relname, $1, $2)
FROM
  pg_class c,
  pg_namespace n
WHERE
  c.relnamespace = n.oid
  AND n.nspname = $2
  AND c.relkind = 'r'
  AND c.relname <> ALL (COALESCE($3,'{}'::text[]));
$$
LANGUAGE sql
SECURITY DEFINER;


/**********************************************************
* SEQUENCE SCHEMA STATE
*
* Adds sequences to the created target schema by querying the
* recent sequences of the source schema. This is only necessary
* if new data will be inserted in a previous database state.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.sequence_schema_state(
  target_schema_name TEXT,
  original_schema_name TEXT DEFAULT 'public'::text
  ) RETURNS SETOF VOID AS
$$
DECLARE
  seq TEXT;
  seq_value INTEGER;
BEGIN
  -- copy or move sequences
  FOR seq IN
    SELECT
      c.relname
    FROM
      pg_class c,
      pg_namespace n
    WHERE
      c.relnamespace = n.oid
      AND n.nspname = $2
      AND relkind = 'S'
  LOOP
    SELECT nextval(quote_ident($2) || '.' || quote_ident(seq)) INTO seq_value;
    IF seq_value > 1 THEN
      seq_value = seq_value - 1;
    END IF;
    EXECUTE format('CREATE SEQUENCE %I.%I START ' || seq_value, $1, seq);
  END LOOP;
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;


/**********************************************************
* MOVE (or COPY) TABLE STATE
*
* Allows for moving or copying tables to another schema.
* This can be useful when resetting the production state
* by using an already restored state. In this case the
* content of the production schema should be removed and
* the content of the restored state would be moved.
* Triggers for tables would have to be created again.
***********************************************************/
CREATE OR REPLACE FUNCTION pgmemento.move_table_state(
  table_name TEXT,
  target_schema_name TEXT,
  source_schema_name TEXT,
  copy_data BOOLEAN DEFAULT TRUE
  ) RETURNS SETOF VOID AS
$$
BEGIN
  IF $4 THEN
    EXECUTE format('CREATE TABLE %I.%I AS SELECT * FROM %I.%I', $2, $1, $3, $1);
  ELSE
    EXECUTE format('ALTER TABLE %I.%I SET SCHEMA %I', $3, $1, $2);
  END IF;
END;
$$
LANGUAGE plpgsql STRICT;

CREATE OR REPLACE FUNCTION pgmemento.move_schema_state(
  target_schema_name TEXT,
  source_schema_name TEXT DEFAULT 'public'::text,
  except_tables TEXT[] DEFAULT '{}',
  copy_data BOOLEAN DEFAULT TRUE
  ) RETURNS SETOF void AS
$$
DECLARE
  seq TEXT;
  seq_value INTEGER;
BEGIN
  -- create new schema
  EXECUTE format('CREATE SCHEMA %I', $1);

  -- copy or move sequences
  FOR seq IN
    SELECT
      c.relname
    FROM
      pg_class c,
      pg_namespace n
    WHERE
      c.relnamespace = n.oid
      AND n.nspname = $2
      AND relkind = 'S'
  LOOP
    IF $4 THEN
      SELECT nextval(quote_ident($2) || '.' || quote_ident(seq)) INTO seq_value;
      IF seq_value > 1 THEN
        seq_value = seq_value - 1;
      END IF;
      EXECUTE format(
        'CREATE SEQUENCE %I.%I START ' || seq_value,
        $1, seq);
    ELSE
      EXECUTE format(
        'ALTER SEQUENCE %I.%I SET SCHEMA %I',
        $2, seq, $1);
    END IF;
  END LOOP;

  -- copy or move tables
  PERFORM
    pgmemento.move_table_state(c.relname, $1, $2, $4)
  FROM
    pg_class c,
    pg_namespace n
  WHERE
    c.relnamespace = n.oid
    AND n.nspname = $2
    AND c.relkind = 'r'
    AND c.relname <> ALL (COALESCE($3,'{}'::text[]));

  -- remove old schema if data were not copied but moved
  IF NOT $4 THEN
    EXECUTE format('DROP SCHEMA %I CASCADE', $2);
  END IF;
END
$$
LANGUAGE plpgsql
SECURITY DEFINER;


/**********************************************************
* DROP TABLE STATE
*
* Drops a schema or table state e.g. if it is of no more use.
* Note: The database schema itself is not dropped.
***********************************************************/
-- truncate and drop table and all depending objects
CREATE OR REPLACE FUNCTION pgmemento.drop_table_state(
  table_name TEXT,
  target_schema_name TEXT DEFAULT 'public'::text
  ) RETURNS SETOF VOID AS
$$
DECLARE
  fkey TEXT;
BEGIN
  -- dropping depending references to given table
  FOR fkey IN
    SELECT
      conname
    FROM
      pg_constraint
    WHERE
      conrelid = pgmemento.get_table_oid($1, $2)
      AND contype = 'f'
  LOOP
    EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I', $2, $1, fkey);
  END LOOP;

  -- hit the log_truncate_trigger
  EXECUTE format('TRUNCATE TABLE %I.%I CASCADE', $2, $1);

  -- dropping the table
  EXECUTE format('DROP TABLE %I.%I CASCADE', $2, $1);
END;
$$
LANGUAGE plpgsql STRICT
SECURITY DEFINER;

-- perform drop_table_state on multiple tables in one schema
CREATE OR REPLACE FUNCTION pgmemento.drop_schema_state(
  target_schema_name TEXT,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS SETOF VOID AS
$$
SELECT
  pgmemento.drop_table_state(c.relname, $1)
FROM
  pg_class c,
  pg_namespace n
WHERE
  c.relnamespace = n.oid
  AND n.nspname = $1
  AND c.relkind = 'r'
  AND c.relname <> ALL (COALESCE($2,'{}'::text[]));
$$
LANGUAGE sql
SECURITY DEFINER;




-- CTL.sql
--
-- Author:      Felix Kunde <felix-kunde@gmx.de>
--
--              This script is free software under the LGPL Version 3
--              See the GNU Lesser General Public License at
--              http://www.gnu.org/copyleft/lgpl.html
--              for more details.
-------------------------------------------------------------------------------
-- About:
-- Script to start auditing for a given database schema
-------------------------------------------------------------------------------
--
-- ChangeLog:
--
-- Version | Date       | Description                                  | Author
-- 0.5.2     2021-12-28   start will call reinit if log params differ    FKun
-- 0.5.1     2021-01-02   fix session_info entries                       FKun
-- 0.5.0     2020-05-04   add revision to version endpoint               FKun
-- 0.4.0     2020-04-19   add reinit endpoint                            FKun
-- 0.3.2     2020-04-16   better support for quoted schemas              FKun
-- 0.3.1     2020-04-11   add drop endpoint                              FKun
-- 0.3.0     2020-03-29   make logging of old data configurable, too     FKun
-- 0.2.0     2020-03-21   write changes to audit_schema_log              FKun
-- 0.1.0     2020-03-15   initial commit                                 FKun
--

/**********************************************************
* C-o-n-t-e-n-t:
*
* FUNCTIONS:
*   drop(schemaname TEXT DEFAULT 'public'::text, log_state BOOLEAN DEFAULT TRUE, drop_log BOOLEAN DEFAULT FALSE, except_tables TEXT[] DEFAULT '{}') RETURNS TEXT
*   init(schemaname TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
*     log_old_data BOOLEAN DEFAULT TRUE, log_new_data BOOLEAN DEFAULT FALSE, log_state BOOLEAN DEFAULT FALSE,
*     trigger_create_table BOOLEAN DEFAULT FALSE, except_tables TEXT[] DEFAULT '{}') RETURNS TEXT
*   reinit(schemaname TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
*     log_old_data BOOLEAN DEFAULT TRUE, log_new_data BOOLEAN DEFAULT FALSE, trigger_create_table BOOLEAN DEFAULT FALSE, except_tables TEXT[] DEFAULT '{}'
*   start(schemaname TEXT DEFAULT 'public'::text, audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
*     log_old_data BOOLEAN DEFAULT TRUE, log_new_data BOOLEAN DEFAULT FALSE, trigger_create_table BOOLEAN DEFAULT FALSE,
*     except_tables TEXT[] DEFAULT '{}') RETURNS TEXT
*   stop(schemaname TEXT DEFAULT 'public'::text, except_tables TEXT[] DEFAULT '{}') RETURNS TEXT
*   version(OUT full_version TEXT, OUT major_version INTEGER, OUT minor_version INTEGER, OUT revision INTEGER,
*     OUT build_id TEXT) RETURNS RECORD
*
***********************************************************/

CREATE OR REPLACE FUNCTION pgmemento.init(
  schemaname TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
  log_old_data BOOLEAN DEFAULT TRUE,
  log_new_data BOOLEAN DEFAULT FALSE,
  log_state BOOLEAN DEFAULT FALSE,
  trigger_create_table BOOLEAN DEFAULT FALSE,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS TEXT AS
$$
DECLARE
  schema_quoted TEXT;
  txid_log_id INTEGER;
BEGIN
  -- make sure schema is quoted no matter how it is passed to init
  schema_quoted := quote_ident(pgmemento.trim_outer_quotes($1));

  -- check if schema is already logged
  IF EXISTS (
    SELECT
      1
    FROM
      pgmemento.audit_schema_log
    WHERE
      schema_name = pgmemento.trim_outer_quotes($1)
      AND upper(txid_range) IS NULL
  ) THEN
    RETURN format('pgMemento is already intialized for %s schema.', schema_quoted);
  END IF;

  -- log transaction that initializes pgMemento for a schema
  -- and store configuration in session_info object
  PERFORM set_config(
    'pgmemento.session_info', '{"pgmemento_init": ' ||
    jsonb_build_object(
      'schema_name', $1,
      'default_audit_id_column', $2,
      'default_log_old_data', $3,
      'default_log_new_data', $4,
      'log_state', $5,
      'trigger_create_table', $6,
      'except_tables', $7)::text
      || '}',
    TRUE
  );
  txid_log_id := pgmemento.log_transaction(txid_current());

  -- insert new entry in audit_schema_log
  INSERT INTO pgmemento.audit_schema_log
    (log_id, schema_name, default_audit_id_column, default_log_old_data, default_log_new_data, trigger_create_table, txid_range)
  VALUES
    (nextval('pgmemento.schema_log_id_seq'), $1, $2, $3, $4, $6,
     numrange(txid_log_id, NULL, '(]'));

  -- create event trigger to log schema changes
  PERFORM pgmemento.create_schema_event_trigger($6);

  -- start auditing for tables in given schema'
  PERFORM pgmemento.create_schema_audit(pgmemento.trim_outer_quotes($1), $2, $3, $4, $5, $6, $7);

  RETURN format('pgMemento is initialized for %s schema.', schema_quoted);
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pgmemento.reinit(
  schemaname TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
  log_old_data BOOLEAN DEFAULT TRUE,
  log_new_data BOOLEAN DEFAULT FALSE,
  trigger_create_table BOOLEAN DEFAULT FALSE,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS TEXT AS
$$
DECLARE
  schema_quoted TEXT;
  current_audit_schema_log pgmemento.audit_schema_log%ROWTYPE;
  txid_log_id INTEGER;
  rec RECORD;
BEGIN
  -- make sure schema is quoted no matter how it is passed to reinit
  schema_quoted := quote_ident(pgmemento.trim_outer_quotes($1));

  -- check if schema is already logged
  SELECT
    *
  INTO
    current_audit_schema_log
  FROM
    pgmemento.audit_schema_log
  WHERE
    schema_name = pgmemento.trim_outer_quotes($1)
  ORDER BY
    id DESC
  LIMIT 1;

  IF current_audit_schema_log.id IS NULL THEN
    RETURN format('pgMemento has never been intialized for %s schema. Run init instread.', schema_quoted);
  END IF;

  IF upper(current_audit_schema_log.txid_range) IS NOT NULL THEN
    RETURN format('pgMemento is already dropped from %s schema. Run init instead.', schema_quoted);
  END IF;

  -- log transaction that reinitializes pgMemento for a schema
  -- and store configuration in session_info object
  PERFORM set_config(
    'pgmemento.session_info', '{"pgmemento_reinit": ' ||
    jsonb_build_object(
      'schema_name', $1,
      'default_audit_id_column', $2,
      'default_log_old_data', $3,
      'default_log_new_data', $4,
      'trigger_create_table', $5,
      'except_tables', $6)::text
    || '}', 
    TRUE
  );
  txid_log_id := pgmemento.log_transaction(txid_current());

  -- configuration differs, so reinitialize
  IF current_audit_schema_log.default_audit_id_column != $2
     OR current_audit_schema_log.default_log_old_data != $3
     OR current_audit_schema_log.default_log_new_data != $4
     OR current_audit_schema_log.trigger_create_table != $5
  THEN
    UPDATE pgmemento.audit_schema_log
       SET txid_range = numrange(lower(txid_range), txid_log_id::numeric, '(]')
     WHERE id = current_audit_schema_log.id;

    -- create new entry in audit_schema_log
    INSERT INTO pgmemento.audit_schema_log
      (log_id, schema_name, default_audit_id_column, default_log_old_data, default_log_new_data, trigger_create_table, txid_range)
    VALUES
      (current_audit_schema_log.log_id, $1, $2, $3, $4, $5,
       numrange(txid_log_id, NULL, '(]'));
  END IF;

  -- recreate auditing if parameters differ
  FOR rec IN
    SELECT
      c.relname AS table_name,
      n.nspname AS schema_name,
      at.audit_id_column
    FROM
      pg_class c
    JOIN
      pg_namespace n
      ON c.relnamespace = n.oid
    JOIN pgmemento.audit_tables at
      ON at.tablename = c.relname
     AND at.schemaname = n.nspname
     AND tg_is_active
    WHERE
      n.nspname = pgmemento.trim_outer_quotes($1)
      AND c.relkind = 'r'
      AND c.relname <> ALL (COALESCE($6,'{}'::text[]))
      AND (at.audit_id_column IS DISTINCT FROM $2
       OR at.log_old_data IS DISTINCT FROM $3
       OR at.log_new_data IS DISTINCT FROM $4)
  LOOP
    -- drop auditing from table but do not log or drop anything
    PERFORM pgmemento.drop_table_audit(rec.table_name, rec.schema_name, rec.audit_id_column, FALSE, FALSE);

    -- log reinit event to keep log_id in audit_table_log
    PERFORM pgmemento.log_table_event(rec.table_name, rec.schema_name, 'REINIT TABLE');

    -- recreate auditing
    PERFORM pgmemento.create_table_audit(rec.table_name, rec.schema_name, $2, $3, $4, FALSE);
  END LOOP;

  -- update event triggers
  IF $5 != current_audit_schema_log.trigger_create_table THEN
    PERFORM pgmemento.create_schema_event_trigger($5);
  END IF;

  RETURN format('pgMemento is reinitialized for %s schema.', schema_quoted);
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pgmemento.start(
  schemaname TEXT DEFAULT 'public'::text,
  audit_id_column_name TEXT DEFAULT 'pgmemento_audit_id'::text,
  log_old_data BOOLEAN DEFAULT TRUE,
  log_new_data BOOLEAN DEFAULT FALSE,
  trigger_create_table BOOLEAN DEFAULT FALSE,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS TEXT AS
$$
DECLARE
  schema_quoted TEXT;
  current_audit_schema_log pgmemento.audit_schema_log%ROWTYPE;
  txid_log_id INTEGER;
  reinit_test TEXT := '';
BEGIN
  -- make sure schema is quoted no matter how it is passed to start
  schema_quoted := quote_ident(pgmemento.trim_outer_quotes($1));

  -- check if schema is already logged
  SELECT
    *
  INTO
    current_audit_schema_log
  FROM
    pgmemento.audit_schema_log
  WHERE
    schema_name = pgmemento.trim_outer_quotes($1)
    AND upper(txid_range) IS NULL;

  IF current_audit_schema_log.id IS NULL THEN
    RETURN format('pgMemento is not yet intialized for %s schema. Run init first.', schema_quoted);
  END IF;

  -- log transaction that starts pgMemento for a schema
  -- and store configuration in session_info object
  PERFORM set_config(
    'pgmemento.session_info', '{"pgmemento_start": ' ||
    jsonb_build_object(
      'schema_name', $1,
      'default_audit_id_column', $2,
      'default_log_old_data', $3,
      'default_log_new_data', $4,
      'trigger_create_table', $5,
      'except_tables', $6)::text
    || '}',
    TRUE
  );
  txid_log_id := pgmemento.log_transaction(txid_current());

  -- enable triggers where they are not active
  PERFORM
    pgmemento.create_table_log_trigger(c.relname, $1, at.audit_id_column, asl.default_log_old_data, asl.default_log_new_data)
  FROM
    pg_class c
  JOIN
    pg_namespace n
    ON c.relnamespace = n.oid
  JOIN
    pgmemento.audit_schema_log asl
    ON asl.schema_name = n.nspname
   AND lower(asl.txid_range) IS NOT NULL
   AND upper(asl.txid_range) IS NULL
  JOIN pgmemento.audit_tables at
    ON at.tablename = c.relname
   AND at.schemaname = n.nspname
   AND NOT tg_is_active
  WHERE
    n.nspname = pgmemento.trim_outer_quotes($1)
    AND c.relkind = 'r'
    AND c.relname <> ALL (COALESCE($6,'{}'::text[]));

  -- configuration differs, perform reinit
  IF current_audit_schema_log.default_log_old_data != $3
     OR current_audit_schema_log.default_log_new_data != $4
     OR current_audit_schema_log.trigger_create_table != $5
  THEN
    PERFORM pgmemento.reinit($1, $2, $3, $4, $5, $6);
    reinit_test := ' and reinitialized';
  END IF;

  RETURN format('pgMemento is started%s for %s schema.', reinit_test, schema_quoted);
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pgmemento.stop(
  schemaname TEXT DEFAULT 'public'::text,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS TEXT AS
$$
DECLARE
  schema_quoted TEXT;
BEGIN
  -- make sure schema is quoted no matter how it is passed to stop
  schema_quoted := quote_ident(pgmemento.trim_outer_quotes($1));

  -- check if schema is already logged
  IF NOT EXISTS (
    SELECT
      1
    FROM
      pgmemento.audit_schema_log
    WHERE
      schema_name = pgmemento.trim_outer_quotes($1)
      AND upper(txid_range) IS NULL
  ) THEN
    RETURN format('pgMemento is not intialized for %s schema. Nothing to stop.', schema_quoted);
  END IF;

  -- log transaction that stops pgMemento for a schema
  -- and store configuration in session_info object
  PERFORM set_config('pgmemento.session_info', '{"pgmemento_stop": ' ||
    jsonb_build_object(
      'schema_name', $1,
      'except_tables', $2)::text
    || '}',
     TRUE
  );
  PERFORM pgmemento.log_transaction(txid_current());

  -- drop log triggers for all tables except those from passed array
  PERFORM pgmemento.drop_schema_log_trigger(pgmemento.trim_outer_quotes($1), $2);

  IF $2 IS NOT NULL AND array_length($2, 1) > 0 THEN
    -- check if excluded tables are still audited
    IF EXISTS (
      SELECT 1
        FROM pgmemento.audited_tables at
        JOIN unnest($2) AS t(audit_table)
          ON t.audit_table = at.tablename
         AND at.schemaname = pgmemento.trim_outer_quotes($1)
       WHERE tg_is_active
    ) THEN
      RETURN format('pgMemento is partly stopped for %s schema.', schema_quoted);
    END IF;
  END IF;

  RETURN format('pgMemento is stopped for %s schema.', schema_quoted);
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pgmemento.drop(
  schemaname TEXT DEFAULT 'public'::text,
  log_state BOOLEAN DEFAULT TRUE,
  drop_log BOOLEAN DEFAULT FALSE,
  except_tables TEXT[] DEFAULT '{}'
  ) RETURNS TEXT AS
$$
DECLARE
  schema_quoted TEXT;
  current_schema_log_id INTEGER;
  current_schema_log_range numrange;
  txid_log_id INTEGER;
BEGIN
  -- make sure schema is quoted no matter how it is passed to drop
  schema_quoted := quote_ident(pgmemento.trim_outer_quotes($1));

  -- check if schema is already logged
  SELECT
    id,
    txid_range
  INTO
    current_schema_log_id,
    current_schema_log_range
  FROM
    pgmemento.audit_schema_log
  WHERE
    schema_name = pgmemento.trim_outer_quotes($1)
  ORDER BY
    id DESC
  LIMIT 1;

  IF current_schema_log_id IS NULL THEN
    RETURN format('pgMemento is not intialized for %s schema. Nothing to drop.', schema_quoted);
  END IF;

  IF upper(current_schema_log_range) IS NOT NULL THEN
    RETURN format('pgMemento is already dropped from %s schema.', schema_quoted);
  END IF;

  -- log transaction that drops pgMemento from a schema
  -- and store configuration in session_info object
  PERFORM set_config(
    'pgmemento.session_info', '{"pgmemento_drop": ' ||
    jsonb_build_object(
      'schema_name', $1,
      'log_state', $2,
      'drop_log', $3,
      'except_tables', $4)::text
    || '}',
    TRUE
  );
  txid_log_id := pgmemento.log_transaction(txid_current());

  -- drop auditing for all tables except those from passed array
  PERFORM pgmemento.drop_schema_audit(pgmemento.trim_outer_quotes($1), $2, $3, $4);

  IF $4 IS NOT NULL AND array_length($4, 1) > 0 THEN
    -- check if excluded tables are still audited
    IF EXISTS (
      SELECT 1
        FROM pgmemento.audited_tables at
        JOIN unnest($4) AS t(audit_table)
          ON t.audit_table = at.tablename
         AND at.schemaname = pgmemento.trim_outer_quotes($1)
       WHERE tg_is_active
    ) THEN
      RETURN format('pgMemento is partly dropped from %s schema.', schema_quoted);
    END IF;
  END IF;

  -- close txid_range for audit_schema_log entry
  UPDATE pgmemento.audit_schema_log
     SET txid_range = numrange(lower(txid_range), txid_log_id::numeric, '(]')
   WHERE id = current_schema_log_id;

  RETURN format('pgMemento is dropped from %s schema.', schema_quoted);
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pgmemento.version(
  OUT full_version TEXT,
  OUT major_version INTEGER,
  OUT minor_version INTEGER,
  OUT revision INTEGER,
  OUT build_id TEXT
  ) RETURNS RECORD AS
$$
SELECT 'pgMemento 0.7.3'::text AS full_version, 0 AS major_version, 7 AS minor_version, 3 AS revision, '92'::text AS build_id;
$$
LANGUAGE sql;




-- make all the data available for pg_dump
do language plpgsql
$$
declare
  name_ varchar;
begin
  for name_ in select sequence_schema || '.' || sequence_name from information_schema.sequences where sequence_schema = 'pgmemento' loop
    perform pg_catalog.pg_extension_config_dump(name_, '');
  end loop;

  for name_ in select table_schema || '.' || table_name from information_schema.tables where table_schema = 'pgmemento' loop
    perform pg_catalog.pg_extension_config_dump(name_, '');
  end loop;
end
$$;
