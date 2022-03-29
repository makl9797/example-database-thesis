# Beschreibung
Dieses Repository ist Teil der Bachelorthesis "Versionsverwaltung mit PostgreSQL bei kollaborativen Anwendungen". Zum Testen und Experimentieren können die Schritte in der untenstehenden Anleitung befolgt werden. Diese helfen bei der Einrichtung der Beispiele und pgAdmin 4 sowie der Durchführung von Benchmarktests mit pgBench. 

Alle benötigten Dateien für pgMemento sind bereits im Repository. Das Original Repository befindet sich hier: https://github.com/pgMemento/pgMemento
# Anleitung
## 1. Docker installieren
Docker für das passende Betriebssystem installieren.
https://www.docker.com/get-started

*Nach der ersten Installation ist oft ein Neustart erforderlich

## 2. Klonen des Github-Repo
Github-Repo klonen oder herunterladen und am Zielort entpacken.

https://github.com/makl9797/example-database-thesis

## 3. Docker Container starten
Im lokalen Repository-Ordner ein Terminal öffnen und folgenden Befehl ausführen:

`docker-compose up --build`

Damit werden alle benötigten Dateien heruntergeladen und die Docker Container gestartet.
## 4. Carhouse-Beispiel laden

Ein neues Terminal öffnen und dort folgenden Befehl eingeben:

`docker exec -it pgcontainer bash`

Damit gelangt man in den Postgres-Container und kann im Container Befehle ausführen.

Dort folgenden Befehl ausführen:

`bash load_examples.sh`

Es werden dadurch folgende 3 Datenbanken erstellt:


| Datenbank              | Inhalt                                                            |
| ---------------------- | ----------------------------------------------------------------- |
| carhouse_db            | Autohaus-Beispiel ohne Versionsverwaltung                         |
| carhouse_versioning_db | Autohaus-Beispiel mit einfacher Versionierung (siehe Kapitel 3.5) |
| carhouse_pgmemento_db  | Autohaus-Beispiel mit pgMemento (siehe Kapitel 3.6-3.7)           | 

## Testskript

Für die Tests wurde ein Bash Skript benutzt um einen oder mehrere Tests durchzuführen. Die Dokumentation zu [pgBench](https://www.postgresql.org/docs/current/pgbench.html) befindet sich in der offiziellen [PostgreSQL Dokumentation](https://www.postgresql.org/docs/current/index.html).

Zum ausführen des Skripts wird folgender Befehl verwendet:

`bash test.sh`

Zum Start kann zwischen der Eingabe von 'a' zum einmaligen Testen und der Eingabe 'b' für mehrere Tests hintereinander gewählt werden.

Zusätzlich können nach der Auswahl die einzelnen Parameter ausgewählt werden sowie die Möglichkeit die Installation von pgMemento zu verhindern. Informationen zu den Parametern und Ergebnissen gibt es in der [pgBench](https://www.postgresql.org/docs/current/pgbench.html) Dokumentation.

Die Ergebnisse für Auswahl 'b' werden in einer .log Datei mit Zeitstempel im Ordner 'results'  gelagert. Dieser befindet sich innerhalb des Containers. Für die Exportierung außerhalb des Containers kann folgender Befehl im normalen Terminal verwendet werden:

`sudo docker cp pgcontainer:/results/ .`

Dadurch wird der 'results' Ordner in das aktuelle Verzeichnis geladen.

## pgAdmin

pgAdmin ist nach dem Start der Container unter folgendem Link erreichbar:

http://localhost:5050/

Die Logindaten für pgAdmin lauten:

Loginname: admin@admin.com
Passwort: root

Anschließend muss eine Verbindung zur Datenbank eingerichtet werden. Den Weg beschreiben folgende Schritte:

- Auf dem Startbildschirm nach dem Login auf "Add new Server" klicken.
Es öffnet sich ein Dialogfenster zur Verbindung mit einer Postgres Datenbank.

- Unter dem Reiter "General" kann bei Name ein beliebiger Name ausgewählt werden. Dies ist der Verbindungsname zur Datenbank.

- Unter dem Reiter "Connection" müssen folgende Parameter eingegeben werden:
```
Hostname/Adresse: pgcontainer
Port: 5432
Maintenance Database: postgres
Username: root
Password: root
Save Password?: On
```

Alle anderen Parameter können unverändert bleiben. Auf der linken Seite lässt sich nun im Datenbankbrowser die gewünschte Datenbank finden.


