FROM postgres:latest
COPY /pgMemento /pgMemento
COPY ./init_and_test.sh /.
COPY ./CREATE_TEMP_DB.sql /.
COPY ./DROP_TEMP_DB.sql /.
COPY ./INIT_CARHOUSE.sql /.
COPY ./carhouse /carhouse
COPY ./INIT_CARHOUSE_VERSIONING.sql /.