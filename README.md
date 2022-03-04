# Anleitung Beispieldatenbank

###### tags: `bachelor`

## 1. Docker installieren
Docker für das passende Betriebssystem installieren.
https://www.docker.com/get-started

*Nach der ersten Installation ist oft ein Neustart erforderlich

## 2. Klonen des Github-Repo
Github-Repo klonen oder herunterladen und am Zielort entpacken.

https://github.com/makl9797/database-bachelor-thesis-mats-klein

## 3. Docker Container starten
Im lokalen Repositoryordner ein Terminal öffnen und folgenden Befehl ausführen:

`docker-compose up --build`

Damit werden alle benötigten Dateien heruntergeladen und der Docker Container gestartet.

## 4. pgAdmin öffnen

pgAdmin ist unter folgendem Link erreichbar:

http://localhost:5050/

Die Logindaten für pgAdmin lauten:

Loginname: admin@admin.com
Passwort: root

## 5. Verbindung zur Postgres Datenbank herstellen

Auf dem Startbildschirm nach dem Login auf "Add new Server" klicken.
Es öffnet sich ein Dialogfenster zur Verbindung mit einer Postgres Datenbank.

Unter dem Reiter "General" kann bei Name ein beliebiger Name ausgewählt werden. Dies ist der Verbindungsname zur Datenbank.

Unter dem Reiter "Connection" müssen folgende Parameter eingegeben werden:

Hostname/Adresse: pgcontainer
Port: 5432
Maintenance Database: postgres
Username: root
Password: root
Save Password?: On

Alle anderen Parameter bleiben unberührt.

## 6. Initialisierung der pgBench Tabellen

Ein neues Terminal öffnen und dort folgenden Befehl eingeben:

`docker exec -it pgcontainer bash`

Damit gelangt man in den Postgres-Container und kann dort Befehle ausfühlen.

Im pgcontainer muss als nächstes folgender Befehl ausgeführt werden:

`pgbench -i -s 1 history_db`

Damit werden die von pgbench benötigen Tabellen erstellt. 

`-i` steht für initialize.
`-s 1` beschreibt den Skalierungsfaktor um den die Anzahl der Tupel multipliziert werden.
`history_db` ist der Name der Datenbank für die pgbench initialisiert werden soll.

Standardmäßig werden folgende Tabellen angelegt:

```
table                   # of rows
---------------------------------
pgbench_branches        1
pgbench_tellers         10
pgbench_accounts        100000
pgbench_history         0
```

#### 7. Beispiel Skalierungsfaktor von 50

```
table                   # of rows
---------------------------------
pgbench_branches        50
pgbench_tellers         500
pgbench_accounts        5000000
pgbench_history         0
```

## 8. Installation und Initialisierung von pgMemento
Die benötigten Dateien für pgMemento werden bereits im Repository mitgeliefert und müssen nicht extra runtergeladen werden.

Zur Installation müssen folgende Befehle im pgcontainer ausgeführt werden:

`cd pgMemento`

um zu den pgMemento Dateien zu gelangen und dann

`psql -h localhost -p 5432 -d history_db -f INSTALL_PGMEMENTO.sql`

um pgMemento zu installieren.

Damit das public-Schema der history_db von pg_memento aufgezeichnet wird, muss pgMemento noch initialisiert werden mit folgendem Befehl innerhalb des pgMemento Ordners:

`psql -h localhost -p 5432 -d history_db -f INIT_HISTORY_DB.sql`

## 9. Ausführen eines pgbench Tests

Um einen pgBench Test auszuführen gibt es folgenden Befehl

`pgbench -c 10 -j 2 -t 10000 history_db`

`-c` gibt an wie viele Clients die Transaktionen ausführen sollen
`-j` gibt an auf wie vielen Threads der Test durchgeführt werden soll
`-t` gibt die Anzahl der Transaktion je Client an (hier 10*10000)
`history_db` gibt wieder an auf welcher Datenbank pgbench ausgeführt werden soll

Das Ergebnis wird in tps (transactions per second) angegeben.




