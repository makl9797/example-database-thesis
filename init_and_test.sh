#!/bin/sh
# init.sh
echo "Start init and test script..."
echo "Detailed information about the parameters can be found in the readme!"
echo "Enter scaling factors (finish with Ctrl+D or Cmd+D): "
while read factor; do
    SCALINGFACTORS=("${SCALINGFACTORS[@]}" $factor)
done

echo "All Factors: "
echo ${SCALINGFACTORS[@]}

echo "Enter number of clients (finish with Ctrl+D or Cmd+D): "
while read client; do
    CLIENTS=("${CLIENTS[@]}" $client)
done
echo "All Factors: "
echo ${CLIENTS[@]}

echo "Enter number of threads (finish with Ctrl+D or Cmd+D): "
while read thread; do
    THREADS=("${THREADS[@]}" $thread)
done
echo "All Factors: "
echo ${THREADS[@]}

echo "Enter number of transactions per client (finish with Ctrl+D or Cmd+D): "
while read transaction; do
    TRANSACTIONS=("${TRANSACTIONS[@]}" $transaction)
done
echo "All Factors: "
echo ${TRANSACTIONS[@]}

EXEC_TIME=$(date +"%Y_%m_%d_%H_%M")
DB=temp_db
HOST=localhost
PORT=5432

echo "create ./results"
mkdir -p results

for s in ${SCALINGFACTORS[@]}; do
    for c in ${CLIENTS[@]}; do
        for j in ${THREADS[@]}; do
            for t in ${TRANSACTIONS[@]}; do
                echo "create temporary test base"
                psql -h $HOST -p $PORT -d postgres -f CREATE_TEMP_DB.sql
                echo "initialize pgbench tables..."
                pgbench -i -s $s $DB
                echo "pgbench tables initialized"
                echo "move into /pgMemento"
                cd pgMemento
                echo "install pgMemento..."
                psql -h $HOST -p $PORT -d $DB -f INSTALL_PGMEMENTO.sql
                echo "pgMemento installed"
                echo "initialize $DB with pgMemento"
                psql -h $HOST -p $PORT -d $DB -f INIT_PGMEMENTO.sql
                echo "$DB initialized"
                echo "move back to root"
                cd ..
                echo "testing base"
                echo "------------------------------------------------------------------------------" >>results/pgbench_results_$EXEC_TIME.log
                pgbench -c $c -j $j -t $t $DB >>results/pgbench_results_$EXEC_TIME.log
                echo "drop temporary test base"
                psql -h $HOST -p $PORT -d postgres -f DROP_TEMP_DB.sql
            done
        done
    done
done

echo "init_and_test.sh finished!"
