#!/bin/sh
# carhouse_script.sh
echo "carhouse_script.sh"
echo "Create database with pgMemento and carhouse data"
DB=carhouse_db
HOST=localhost
PORT=5432
echo "DB = $DB | HOST = $HOST | PORT = $PORT"
psql -h $HOST -p $PORT -d $DB -f INIT_CARHOUSE.sql
cd pgMemento
psql -h $HOST -p $PORT -d $DB -f INSTALL_PGMEMENTO.sql
psql -h $HOST -p $PORT -d $DB -f INIT_PGMEMENTO.sql

echo "finished!"
