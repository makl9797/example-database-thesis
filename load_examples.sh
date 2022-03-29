#!/bin/sh
# start.sh
echo "load_examples.sh"

HOST=localhost
PORT=5432

echo "Create carhouse example bases..."
cd carhouse
psql -h $HOST -p $PORT -d postgres -f init_bases.sql
cd ..
cd pgMemento
psql -h $HOST -p $PORT -d carhouse_pgmemento_db -f INSTALL_PGMEMENTO.sql
psql -h $HOST -p $PORT -d carhouse_pgmemento_db -f INIT_PGMEMENTO.sql
cd ..