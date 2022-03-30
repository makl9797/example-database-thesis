#!/bin/sh
# init.sh
echo "Testing Script"
echo "Run one (a) or multiple (b) tests?"
read MODE

HOST=localhost
PORT=5432

case $MODE in

  a)
    echo "Enter scaling factor: "
    read SCALINGFACTOR
    echo "Enter number of clients: "
    read CLIENTS
    echo "Enter number of threads: "
    read THREADS
    echo "install pgMemento? (y/n)"
    read PGMEMENTO

    psql -h $HOST -p $PORT -U root -d postgres -c "DROP DATABASE IF EXISTS pgbench_db;"
    psql -h $HOST -p $PORT -U root -d postgres -c "CREATE DATABASE pgbench_db;"
    pgbench -i -s $SCALINGFACTOR pgbench_db
    if [[ "$PGMEMENTO" == "y" ]]
    then
    cd pgMemento
    psql -h $HOST -p $PORT -d pgbench_db -f INSTALL_PGMEMENTO.sql
    psql -h $HOST -p $PORT -d pgbench_db -f INIT_PGMEMENTO.sql
    cd ..
    fi
    pgbench -S -c $CLIENTS -j $THREADS -M prepared -T30 pgbench_db
    ;;

  b)
    echo "install pgMemento? (y/n)"
    read PGMEMENTO
    echo "Enter scaling factors (finish with Ctrl+D): "
    while read factor; do
        SCALINGFACTORS=("${SCALINGFACTORS[@]}" $factor)
    done

    echo "Factors: "
    echo ${SCALINGFACTORS[@]}

    echo "Enter number of clients (finish with Ctrl+D): "
    while read client; do
        CLIENTS=("${CLIENTS[@]}" $client)
    done
    echo "Clients: "
    echo ${CLIENTS[@]}

    echo "Enter number of threads (finish with Ctrl+D): "
    while read thread; do
        THREADS=("${THREADS[@]}" $thread)
    done
    echo "Threads: "
    echo ${THREADS[@]}

    EXEC_TIME=$(date +"%Y_%m_%d_%H_%M")

    mkdir -p results

    for s in ${SCALINGFACTORS[@]}; do
        for c in ${CLIENTS[@]}; do
            for j in ${THREADS[@]}; do
                psql -h $HOST -p $PORT -U root -d postgres -c "DROP DATABASE IF EXISTS multi_pgbench_db;"
                psql -h $HOST -p $PORT -U root -d postgres -c "CREATE DATABASE multi_pgbench_db;"
                pgbench -i -s $s multi_pgbench_db
                if [[ "$PGMEMENTO" == "y" ]]
                then
                cd pgMemento
                psql -h $HOST -p $PORT -d multi_pgbench_db -f INSTALL_PGMEMENTO.sql
                psql -h $HOST -p $PORT -d multi_pgbench_db -f INIT_PGMEMENTO.sql
                cd ..
                echo "pgMemento installed">>results/pgbench_results_$EXEC_TIME.log
                fi
                echo "------------------------------------------------------------------------------">>results/pgbench_results_$EXEC_TIME.log
                pgbench -S -c $c -j $j -M prepared -T30 multi_pgbench_db >>results/pgbench_results_$EXEC_TIME.log
            done
        done
    done
    ;;

  *)
    echo "Incorrect input! Please restart script"
    ;;
esac
