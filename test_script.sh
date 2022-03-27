#!/bin/sh
# init.sh
echo "Testing Script"
echo "Creates a temporary db and drops it after the tests"
echo "Enter scaling factor: "
read SCALINGFACTOR
echo "Enter number of clients: "
read CLIENTS
echo "Enter number of transactions: "
read TRANSACTIONS
echo "install pgMemento? (y/n)"
read PGMEMENTO

DB=temp_db
HOST=localhost
PORT=5432
THREADS=2

echo "create temporary test base"
psql -h $HOST -p $PORT -d postgres -f CREATE_TEMP_DB.sql
echo "initialize pgbench tables with a scalefactor of $SCALINGFACTOR..."
pgbench -i -s $SCALINGFACTOR $DB
if [[ $PGMEMENTO -eq 'y' ]]
then
echo "install pgMemento..."
cd pgMemento
psql -h $HOST -p $PORT -d $DB -f INSTALL_PGMEMENTO.sql
echo "initialize pgMemento"
psql -h $HOST -p $PORT -d $DB -f INIT_PGMEMENTO.sql
else
echo "pgMemento not installed"
fi
echo "Running tests with $CLIENTS clients in $THREADS threads with $TRANSACTIONS transactions..."
cd ..
pgbench -c $CLIENTS -j $THREADS -t $TRANSACTIONS $DB 
echo "drop temporary test base"
psql -h $HOST -p $PORT -d postgres -f DROP_TEMP_DB.sql
echo "finished!"
