DROP DATABASE IF EXISTS carhouse_db;
DROP DATABASE IF EXISTS carhouse_versioning_db;
DROP DATABASE IF EXISTS carhouse_pgmemento_db;
CREATE DATABASE carhouse_db;
CREATE DATABASE carhouse_versioning_db;
CREATE DATABASE carhouse_pgmemento_db;

\connect carhouse_db
\i dumps/cars.sql
\i dumps/customers.sql
\i dumps/employees.sql
\i dumps/sellings.sql

\connect carhouse_versioning_db
\i dumps/cars.sql
\i dumps/customers.sql
\i dumps/employees.sql
\i dumps/sellings.sql
\i versioning.sql

\connect carhouse_pgmemento_db
\i dumps/cars.sql
\i dumps/customers.sql
\i dumps/employees.sql
\i dumps/sellings.sql