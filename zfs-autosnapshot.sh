#!/bin/bash
#
# Dieses Bash-Skript automatisiert den Prozess der Erstellung, Übertragung und Verwaltung von ZFS-Snapshots zwischen verschiedenen ZFS-Pools.
# Insgesamt handelt es sich um ein Skript, das ZFS-Snapshots erstellt, überträgt, überwacht und alte Snapshots verwaltet,
# während es Benachrichtigungen über den Prozess per E-Mail verschickt.
#
# Benötigt das Paket "zfs-prune-snapshots":
# 'https://github.com/bahamas10/zfs-prune-snapshots.git'
# Es wird bei der ausführung automatisch installiert.
#
# Autor: Manuel Hampel <hampel.manuel@protonmail.com>
# Datum: August 25, 2023
# Version: 1.1.3



# Definieren der Namen der Pools und den Speicherort für die letzten Snapshot-Informationen und Logs
SOURCE_POOL="mypool"
DEST_POOL="mybackup"
LOG_DIR="/var/log/zfs"
LAST_SNAPSHOT="$LOG_DIR/zfs-last-snapshot.md"
DESTROYED_LOG="$LOG_DIR/zfs-destroyed-snapshots.log"
SNAPCHECK="$LOG_DIR/zfs-snapcheck.log"
EMAIL="6qpx9rybyv@pomail.net"
SOURCE_SNAP_LIFETIME="1M"
DEST_SNAP_LIFETIME="1y"

#
#     ----------------------
#   |                        |
#   |   !! SNAP LIFETIME !!  |
#   |                        |
#   |       s seconds        |
#   |       m minutes        |
#   |       h hours          |
#   |       d days           |
#   |       w weeks          |
#   |       M months         |
#   |       y years          |
#   |                        |
#     ----------------------
#

# Prüfe, ob das Log-Verzeichnis vorhanden ist
if [ -d "$LOG_DIR" ]; then
    :
else
    mkdir -p "$LOG_DIR"
    if [ $? -eq 0 ]; then
        echo "Log-Verzeichnis wurde erfolgreich erstellt."
    else
        echo "Fehler beim Erstellen des Verzeichnisses. Das Skript wird abgebrochen."
        exit 1
    fi
fi

# Prüfen, ob das Paket "zfs-prune-snapshots" installiert ist
if ! command -v zfs-prune-snapshots &>/dev/null; then
    echo "Das Paket 'zfs-prune-snapshots' ist nicht installiert."

    # Frage, ob das Paket über Git installiert werden soll
    read -p "Möchten Sie das Paket 'zfs-prune-snapshots' über Git installieren? (y/n): " install_choice

    if [[ $install_choice == "y" || $install_choice == "Y" ]]; then
        # Prüfe, ob Git installiert ist
        if ! command -v git &>/dev/null; then
            echo "Git ist nicht installiert. Installiere Git..."

                # Funktion zur Installation von Paketen mit apt
                install_with_apt() {
                    sudo apt-get update
                    sudo apt-get install -y git
                }

                # Funktion zur Installation von Paketen mit dnf
                install_with_dnf() {
                    sudo dnf install -y git
                }

                # Funktion zur Installation von Paketen mit yum
                install_with_yum() {
                    sudo yum install -y git
                }

                # Funktion zur Installation von Paketen mit pkg (FreeBSD)
                install_with_pkg() {
                    sudo pkg install -y git
                }

                # Erkennen des Paketmanagers und Ausführung der entsprechenden Installationsroutine
                if command -v apt-get >/dev/null 2>&1; then
                    echo "Apt Paketmanager gefunden"
                    install_with_apt
                elif command -v dnf >/dev/null 2>&1; then
                    echo "DNF Paketmanager gefunden"
                    install_with_dnf
                elif command -v yum >/dev/null 2>&1; then
                    echo "YUM Paketmanager gefunden"
                    install_with_yum
                elif command -v pkg >/dev/null 2>&1; then
                    echo "pkg Paketmanager gefunden"
                    install_with_pkg
                else
                    echo "Das Skript konnte den intallierten Paketmanager nicht identifizieren. Bitte installieren Sie Git manuell, um fortzufahren."
                    exit 1
                fi
        fi

        # Definiere das absolute Verzeichnis
        absolute_dir="/opt/zfs-prune-snapshots"

        # Klone das Git-Repo
        git clone https://github.com/bahamas10/zfs-prune-snapshots.git "$absolute_dir"

        # Kopiere die Datei in /usr/bin/
        sudo cp -r "$absolute_dir/zfs-prune-snapshots" /usr/bin/

        # Prüfe, ob das Kommando nun verfügbar ist
        if command -v zfs-prune-snapshots &>/dev/null; then
            echo -e "\nDas Paket 'zfs-prune-snapshots' wurde erfolgreich installiert und ist nun verfügbar.\n\nfahre fort...\n"
        else
            echo -e "\nDas Paket 'zfs-prune-snapshots' konnte nicht erfolgreich installiert werden.\n\nBitte versuchen Sie Problem zu beheben oder das Paket manuell zu installieren.\n"
            exit 2
        fi
    else
        echo "Das Skript wird abgebrochen."
        exit 3
    fi
fi

# Prüfen, ob die Datei mit dem letzten gesendeten Snapshot vorhanden ist
if [ -f "$LAST_SNAPSHOT" ]; then
    # Der Name des zuletzt gesendeten Snapshots wird aus der angegebenen Datei "zfs-last-snapshot.md" gelesen
    last_sent_snapshot=$(cat "$LAST_SNAPSHOT")
    echo -e "\nEin inkrementeller Snapshot wird erstellt."
else
    last_sent_snapshot=""
    echo -e "\nEin vollständiger Snapshot wird erstellt."
fi

# Initialisieren der Variable, um den Status des ersten Snapshots zu verfolgen
first_snapshot=false

# Prüfen, ob bereits Snapshots vorhanden sind
if [ -n "$last_sent_snapshot" ]; then

    # Ein vorheriger Snapshot wurde gefunden, daher handelt es sich nicht um den ersten Snapshot
    first_snapshot=false
else

    # Es wurde kein vorheriger Snapshot gefunden, daher handelt es sich um den ersten Snapshot
    first_snapshot=true
fi

# Prüfen, ob es der erste Snapshot ist und entsprechend handeln
if [ "$first_snapshot" = true ]; then

    # Ein vollständiger Snapshot, einschließlich aller Sub-Datasets, wird für den Quellpool erstellt, dessen Name das aktuelle Datum und die Uhrzeit enthält
    full_snapshot="$SOURCE_POOL@fullsnapshot_$(date +%d-%m-%Y_%H:%M:%S)"
    zfs snapshot -r "$full_snapshot"

    # Senden des gesamten Snapshots, wenn es sich um den ersten Snapshot handelt
    zfs send -R "$full_snapshot" | zfs receive "$DEST_POOL" -F

    # Der Name des neuen Snapshots wird in der Datei "zfs-last-snapshot.md" gespeichert
    echo "$full_snapshot" > "$LAST_SNAPSHOT"
else

    # Ein neuer inkrementeller Snapshot, einschließlich aller Sub-Datasets, wird für den Quellpool erstellt, dessen Name das aktuelle Datum und die Uhrzeit enthält
    new_snapshot="$SOURCE_POOL@incremental_snapshot_$(date +%d-%m-%Y_%H:%M:%S)"
    zfs snapshot -r "$new_snapshot"

    # Senden der inkrementellen Snapshots an den Zielpool, wenn Snapshots vorhanden sind
    zfs send -R -i "$last_sent_snapshot" "$new_snapshot" | zfs receive "$DEST_POOL" -F

    # Der Name des neuen Snapshots wird in der Datei "zfs-last-snapshot.md" gespeichert
    echo "$new_snapshot" > "$LAST_SNAPSHOT"
fi

# Überprüfen auf Probleme bei der Übertragung und Versand einer E-Mail bei Bedarf
if [ $? -ne 0 ]; then
     echo "Es gab ein Problem mit den zfs-snapshots"
     exit 4
fi

# Der Name des aktuellsten Snapshots im Ziel-Pool wird in die Datei "zfs-snapcheck.log" geschrieben
zfs list -t snapshot -o name,creation -s creation | grep "$DEST_POOL" | tail -n 1 > "$SNAPCHECK"

# Auslesen des Namens des aktuellsten Snapshots aus der Datei "zfs-snapcheck.log"
SNAPCHECK_OUTPUT=$(cat "$SNAPCHECK")

# Nachricht an die Komandozeile
echo -e "\nalle snapshots wurden erfolgreich gesendet.\n\nletzter gesendeter Snapshot:\n"$SNAPCHECK_OUTPUT""

# Eine E-Mail wird mit Informationen über erfolgreich gesendete Snapshots und dem Namen des letzten gesendeten Snapshots gesendet
# printf '%s\n' 'alle zfs-snapshots wurden erfolgreich erstellt und übertragen' 'letzter gesendeter snaphot:' "$SNAPCHECK_OUTPUT" | mail -s "Zfs Send INFO" "$EMAIL\n"

# Lösche alle inkrementellen Snapshots im Quellpool älter als SOURCE_SNAP_LIFETIME
/usr/bin/zfs-prune-snapshots -i -p 'incremental_snapshot_' "$SOURCE_SNAP_LIFETIME" "$SOURCE_POOL" > "$DESTROYED_LOG"

# Lösche alle inkrementellen Snapshots im Zielpool älter als DEST_SNAP_LIFETIME
/usr/bin/zfs-prune-snapshots -i -p 'incremental_snapshot_' "$DEST_SNAP_LIFETIME" "$DEST_POOL" >> "$DESTROYED_LOG"

# Eine E-Mail-Benachrichtigung mit Informationen über gelöschte Snapshots wird gesendet
DESTROYED_OUTPUT=$(cat "$DESTROYED_LOG")
# echo "$DESTROYED_OUTPUT" | mail -s "Zfs Snap-removal INFO" "$EMAIL"

# Nachricht an die Komandozeile
echo -e "\n$DESTROYED_OUTPUT\n"

exit
