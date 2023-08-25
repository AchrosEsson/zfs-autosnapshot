Dieses Bash-Skript automatisiert den Prozess der Erstellung, Übertragung und Verwaltung von ZFS-Snapshots zwischen verschiedenen ZFS-Pools.

Insgesamt handelt es sich um ein Skript, das ZFS-Snapshots erstellt, überträgt, überwacht und alte Snapshots verwaltet,
während es Benachrichtigungen über den Prozess per E-Mail verschickt.

Benötigt das Paket "zfs-prune-snapshots":
'https://github.com/bahamas10/zfs-prune-snapshots.git'

Es wird bei der ausführung automatisch installiert.

1. Es werden die Namen der Quell- und Ziel-Pools sowie Dateipfade für Snapshot-Informationen definiert.

2. Der Name des zuletzt gesendeten Snapshots wird aus der angegebenen Datei "last-snapshot.md" gelesen.

3. Ein neuer inkrementeller Snapshot wird für den Quellpool erstellt, dessen Name das aktuelle Datum und die Uhrzeit enthält.
   Wenn ein letzter gesendeter Snapshot vorhanden ist:

5. Es wird ein inkrementeller Snapshot zwischen dem letzten gesendeten Snapshot und dem neuen Snapshot erstellt.

6. Der neu erstellte inkrementelle Snapshot wird an den Ziel-Pool gesendet.

7. Wenn kein letzter gesendeter Snapshot vorhanden ist, wird eine E-Mail-Benachrichtigung gesendet und das Skript beendet.

8. Der Name des neuen Snapshots wird in der Datei "last-snapshot.md" gespeichert.

9. Der Name des aktuellsten Snapshots im Ziel-Pool wird in die Datei "zfs-snapcheck.log" geschrieben.

10. Der Name des aktuellsten Snapshots wird aus der Datei "zfs-snapcheck.log" gelesen und angezeigt.

11. Eine E-Mail wird mit Informationen über erfolgreich gesendete Snapshots und den Namen des letzten gesendeten Snapshots gesendet.

12. Es werden alte Snapshots gelöscht:
    - Snapshots im Quellpool ("rpool"), die älter als eine Woche sind.
    - Snapshots im Ziel-Pool ("storage"), die älter als 6 Monate sind.

13. Eine E-Mail-Benachrichtigung mit Informationen über gelöschte Snapshots wird gesendet.

14. Das Skript wird beendet.