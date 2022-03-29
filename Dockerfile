FROM postgres:latest
COPY /pgMemento /pgMemento
COPY /carhouse /carhouse
COPY /load_examples.sh /.