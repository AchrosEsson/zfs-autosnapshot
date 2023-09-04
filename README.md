ZFS Auto-Snapshot
===================

Dieses Bash-Skript automatisiert den Prozess der Erstellung, Übertragung und Verwaltung von ZFS-Snapshots zwischen verschiedenen ZFS-Pools.
Insgesamt handelt es sich um ein Skript, das ZFS-Snapshots erstellt, überträgt, überwacht und alte Snapshots verwaltet,
während es Benachrichtigungen über den Prozess per E-Mail verschickt.

## Anforderungen
- [zfs-prune-snapshots](https://github.com/bahamas10/zfs-prune-snapshots.git): Dieses Paket wird automatisch während der Ausführung installiert.

## Autor
- Manuel Hampel <hampel.manuel@protonmail.com>

## Datum
- 25. August 2023

## Version
- 2.1.3

## Konfiguration
- Das Skript speichert Konfigurationsdateien im Verzeichnis `$HOME/.config/zfs-autosnapshot`.

## Beschreibung
Dieses Bash-Skript automatisiert den Prozess der Erstellung, Übertragung und Verwaltung von ZFS-Snapshots. Es bietet folgende Funktionen:
- Erstellung von vollständigen und inkrementellen Snapshots eines ZFS-Quell-Pools.
- Übertragung von Snapshots auf einen Zielpool.
- Überwachung und Verwaltung von Snapshots, einschließlich der Löschung alter Snapshots.
- Senden von E-Mail-Benachrichtigungen während des Prozesses.

## Verwendungshinweise
1. Führen Sie das Skript mit der Option `-config` aus, um die Einstellungen interaktiv zu konfigurieren.
2. Wählen Sie den Quell- und Zielpool aus.
3. Definieren Sie das Verzeichnis für die Protokollierung, die Lebensdauer der Snapshots und die E-Mail-Einstellungen (optional).
4. Bestätigen Sie die Einstellungen.
5. Das Skript erstellt und verwaltet Snapshots und überträgt sie zwischen den Pools.
6. Es entfernt auch alte Snapshots gemäß den angegebenen Lebensdauern.

## Hinweise
Für detaillierte Verwendungshinweise und Optionen finden Sie in den Kommentaren im Skript.

