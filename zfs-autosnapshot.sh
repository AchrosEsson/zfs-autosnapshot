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
SOURCE_POOL="rpool"
DEST_POOL="storage"
SNAPSHOT_FILE="/root/last-snapshot.md"
DESTROYED_LOG="/root/zfs-destroyed-snapshots.log"
SNAPCHECK="/root/zfs-snapcheck.log"
EMAIL="6qpx9rybyv@pomail.net"

# Prüfen, ob das Paket "zfs-prune-snapshots" installiert ist
if ! command -v zfs-prune-snapshots &>/dev/null; then
    echo "Das Paket 'zfs-prune-snapshots' ist nicht installiert."

    # Frage, ob das Paket über Git installiert werden soll
    read -p "Möchten Sie das Paket 'zfs-prune-snapshots' über Git installieren? (y/n): " install_choice

    if [[ $install_choice == "y" || $install_choice == "Y" ]]; then
        # Prüfe, ob Git installiert ist
        if ! command -v git &>/dev/null; then
            echo "Git ist nicht installiert. Installiere Git..."
            sudo apt-get update
            sudo apt-get install git -y
        fi

        # Definiere das absolute Verzeichnis
        absolute_dir="/opt/zfs-prune-snapshots"

        # Klone das Git-Repo
        git clone https://github.com/bahamas10/zfs-prune-snapshots.git "$absolute_dir"

        # Kopiere die Datei in /usr/bin/
        sudo cp -r "$absolute_dir/zfs-prune-snapshots" /usr/bin/

        # Prüfe, ob das Kommando nun verfügbar ist
        if command -v zfs-prune-snapshots &>/dev/null; then
            echo
            echo "Das Paket 'zfs-prune-snapshots' wurde erfolgreich installiert und ist nun verfügbar."
            echo
            echo "fahre fort..."
            echo
        else
            echo
            echo "Das Paket 'zfs-prune-snapshots' konnte nicht erfolgreich installiert werden."
            echo "Bitte versuche das Problem zu beheben oder das Paket manuell zu installieren."
            echo
            exit 1
        fi
    else
        echo "Das Skript wird abgebrochen."
        exit 2
    fi
fi

# Der Name des zuletzt gesendeten Snapshots wird aus der angegebenen Datei "last-snapshot.md" gelesen
last_sent_snapshot=$(cat "$SNAPSHOT_FILE")

# Ein neuer inkrementeller Snapshot wird für den Quellpool erstellt, dessen Name das aktuelle Datum und die Uhrzeit enthält
new_snapshot="$SOURCE_POOL@incremental_snapshot_$(date +%d-%m-%Y_%H:%M:%S)"
zfs snapshot -r "$new_snapshot"

# Senden des inkrementellen Snapshots an den Zielpool, wenn der letzte gesendete Snapshot vorhanden ist
if [ -n "$last_sent_snapshot" ]; then
    zfs send -R -i "$last_sent_snapshot" "$new_snapshot" | zfs receive "$DEST_POOL" -F
else

     # Senden einer Mail und exit, falls es ein Problem bei der Übertragung oder Versionierung gibt
     echo "es gab ein Problem mit den zfs-snapshots" | mail -s "Zfs Send ALERT" "$EMAIL"



#                 ---------------------------------------------------------------------------
#               |                                                                             |
#               |                  !! BEIM ERSTEN AUSFÜHREN AUSKOMMENTIEREN !!                |
#               |                                                                             |
#               |      # Senden des gesamten Snapshot, falls dies der erste Snapshot ist      |
        ### <-- |      zfs send -R "$new_snapshot" | zfs receive "$DEST_POOL"                 |
#               |                                                                             |
#                 ---------------------------------------------------------------------------



fi

# Der Name des neuen Snapshots wird in der Datei "last-snapshot.md" gespeichert
echo "$new_snapshot" > "$SNAPSHOT_FILE"

# Der Name des aktuellsten Snapshots im Ziel-Pool wird in die Datei "zfs-snapcheck.log" geschrieben
zfs list -t snapshot -o name,creation -s creation | grep storage/ROOT | tail -n 1 > "$SNAPCHECK"

# Auslesen des Namens des aktuellsten Snapshots aus der Datei "zfs-snapcheck.log"
SNAPCHECK_OUTPUT=$(cat "$SNAPCHECK")

# Nachricht an die Komandozeile
echo
echo "alle wurden snapshots erfolgreich gesendet"
echo
echo " letzter gesendeter snaphot:"
echo " $SNAPCHECK_OUTPUT"
echo

# Eine E-Mail wird mit Informationen über erfolgreich gesendete Snapshots und den Namen des letzten gesendeten Snapshots gesendet
printf '%s\n' 'alle zfs-snapshots wurden erfolgreich erstellt und übertragen' 'letzter gesendeter snaphot:' "$SNAPCHECK_OUTPUT" | mail -s "Zfs Send INFO" "$EMAIL"

# Lösche alle Snapshots im Quellpool älter als 1 Monat
/usr/bin/zfs-prune-snapshots 1M "$SOURCE_POOL" > zfs-destroyed-snapshots.log

# Lösche alle Snapshots im Zielpool älter als 1 Jahr
/usr/bin/zfs-prune-snapshots 1y "$DEST_POOL" >> zfs-destroyed-snapshots.log

# Eine E-Mail-Benachrichtigung mit Informationen über gelöschte Snapshots wird gesendet
DESTROYED_OUTPUT=$(cat "$DESTROYED_LOG")
echo "$DESTROYED_OUTPUT" | mail -s "Zfs Snap-removal INFO" "$EMAIL"

exit
