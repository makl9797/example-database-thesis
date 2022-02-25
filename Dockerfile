FROM postgres:latest
RUN apt-get update && apt-get install make
COPY /pgMemento /pgMemento
WORKDIR /pgMemento
RUN make install
WORKDIR /..