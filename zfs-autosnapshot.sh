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
# Version: 2.1.3

# Definieren des Speicherorts für die letzten Konfigurationsdateien
CONFIG_DIR="$HOME/.config/zfs-autosnapshot"
CONFIG_FILE="$CONFIG_DIR/zfs_config.conf"
CONFIG_FLAG="-config"
FIRST_RUN_FLAG="$CONFIG_DIR/zfs_first_run"

# Lade Config-Datei
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    mkdir -p "$CONFIG_DIR"
fi

# Überprüfen, ob das Log-Verzeichnis existiert, wenn das Skript nicht zum ersten Mal ausgeführt wird
if [ -f $FIRST_RUN_FLAG ]; then
    if [ -d "$LOG_DIR" ]; then
        :
    else
        echo -e "\nDas Log-Verzeichnis existiert nicht, bitte konfigurieren Sie die Einstellungen erneut.\n\nIhre vorherige Einstellungen:\n"
        cat $CONFIG_FILE
        CONFIG_MODE=true
        echo
    fi
fi

if [ "$1" = "$CONFIG_FLAG" ]; then
    CONFIG_MODE=true
fi

# Überprüfen, ob das Skript zum ersten mal ausgeführt wird
if [ ! -f "$FIRST_RUN_FLAG" ]; then
    echo -e "\nDieses Bash-Skript automatisiert den Prozess der Erstellung, Übertragung und Verwaltung von ZFS-Snapshots zwischen verschiedenen ZFS-Pools."
    echo "Insgesamt handelt es sich um ein Skript, das ZFS-Snapshots erstellt, überträgt, überwacht und alte Snapshots verwaltet,"
    echo -e "während es Benachrichtigungen über den Prozess per E-Mail verschickt.\n"
    echo "Benötigt das Paket "zfs-prune-snapshots":"
    echo "'https://github.com/bahamas10/zfs-prune-snapshots.git'"
    echo "Es wird bei der ausführung automatisch installiert."
fi

if [ "$CONFIG_MODE" = true ] || [ ! -f "$FIRST_RUN_FLAG" ]; then

    # Überprüfen, ob das Config-Verzeichnis existiert
    if [ -d "$CONFIG_DIR" ]; then
        # Erstelle Config-Verzeichnis
        mkdir -p "$CONFIG_DIR"
    fi

    # Überprüfen, ob das First-Run-Flag existiert
    if [ ! -f "$FIRST_RUN_FLAG" ]; then
    echo -e "\nDefinieren Sie die Standardwerte für die Variablen.\n"
    fi

    # Überprüfen, ob das Config-Mode aktiv ist
    if [ "$CONFIG_MODE" = true ]; then
        echo -e "\nBitte konfigurieren Sie die Einstellungen erneut.\n\nIhre vorherige Einstellungen:\n"
        
        # Ausgabe der vorherigen Einstellungen
        echo "Quell-Pool: $SOURCE_POOL"
        echo "Ziel-Pool: $DEST_POOL"
        echo "Log-Verzeichnis: $LOG_DIR"
        echo "Pfad zur Log-Datei für den letzten Snapshot: $LAST_SNAPSHOT"
        echo "Pfad zur Log-Datei für gelöschte Snapshots: $DESTROYED_LOG"
        echo "Pfad zur Log-Datei für Snapshot-Checks: $SNAPCHECK"
        echo "Lebenszeit der Quellpool-Snapshots: $SOURCE_SNAP_LIFETIME"
        echo "Lebenszeit der Zielpool-Snapshots: $DEST_SNAP_LIFETIME"
        if [[ -n "$EMAIL_ADDRESS" ]]; then
            echo "E-Mail-Adresse: $EMAIL_ADDRESS"
        fi
    fi

    # Zeige die verfügbaren ZFS-Pools mit Nummern an
    pools=($(zpool list -H -o name))
    num_pools=${#pools[@]}

    if [ $num_pools -eq 0 ]; then
        echo -e "\nEs sind keine ZFS-Pools verfügbar.\n"
        exit 1
    fi

    echo -e "\nVerfügbare ZFS-Pools:\n"
    for i in "${!pools[@]}"; do
        echo "$i. ${pools[$i]}"
    done

    # Eingabe des Quell-Pools
    while true; do
        echo
        read -p "Wählen Sie den Quell-Pool (Nummer): " source_pool_num

        if [[ ! $source_pool_num =~ ^[0-9]+$ ]] || [ $source_pool_num -lt 0 ] || [ $source_pool_num -ge $num_pools ]; then
            echo -e "\nUngültige Auswahl für den Quell-Pool."
        else
            SOURCE_POOL="${pools[$source_pool_num]}"
            break  # Gültige Auswahl, Schleife verlassen
        fi
    done

    # Eingabe des Ziel-Pools
    while true; do
        read -p "Wählen Sie den Ziel-Pool (Nummer): " dest_pool_num

        if [[ ! $dest_pool_num =~ ^[0-9]+$ ]] || [ $dest_pool_num -lt 0 ] || [ $dest_pool_num -ge $num_pools ]; then
            echo -e "\nUngültige Auswahl für den Ziel-Pool."
        else
            DEST_POOL="${pools[$dest_pool_num]}"
            break  # Gültige Auswahl, Schleife verlassen
        fi
    done

    echo -e "\nAusgewählter Quell-Pool: $SOURCE_POOL"
    echo "Ausgewählter Ziel-Pool: $DEST_POOL"

    DEFAULT_LOG_DIR="/var/log/zfs"
    echo -e "\nBitte geben Sie ein Log-Verzeichnis an\n"
    read -p "Log-Verzeichnis [$DEFAULT_LOG_DIR]: " TEMP_LOG_DIR
    TEMP_LOG_DIR=${TEMP_LOG_DIR:-$DEFAULT_LOG_DIR}

    LAST_SNAPSHOT="$TEMP_LOG_DIR/zfs-last-snapshot.md"
    DESTROYED_LOG="$TEMP_LOG_DIR/zfs-destroyed-snapshots.md"
    SNAPCHECK="$TEMP_LOG_DIR/zfs-snapcheck.log"

    echo
    echo -e "     ----------------------   "
    echo -e "   |                        | "
    echo -e "   |   !! SNAP LIFETIME !!  | "
    echo -e "   |                        | "
    echo -e "   |       s seconds        | "
    echo -e "   |       m minutes        | "
    echo -e "   |       h hours          | "
    echo -e "   |       d days           | "
    echo -e "   |       w weeks          | "
    echo -e "   |       M months         | "
    echo -e "   |       y years          | "
    echo -e "   |                        | "
    echo -e "   |       z.B.: 1w         | "
    echo -e "   |                        | "
    echo -e "     ----------------------   "
    echo

    read -p "Lebenszeit der Quellpool-Snapshots: " SOURCE_SNAP_LIFETIME
    read -p "Lebenszeit der Zielpool-Snapshots: " DEST_SNAP_LIFETIME

    # Frage den Benutzer, ob E-Mails gesendet werden sollen
    while true; do
        echo
        read -p "Möchten Sie E-Mails senden? (y/n): " send_emails

        if [[ "$send_emails" == "y" || "$send_emails" == "Y" ]]; then
            # Frage nach der E-Mail-Adresse
            echo
            read -p "Geben Sie Ihre E-Mail-Adresse ein: " TEMP_EMAIL_ADDRESS

            if [[ -z "TEMP_EMAIL_ADDRESS" ]]; then
                echo -e "\nSie haben keine E-Mail-Adresse eingegeben. Bitte versuchen Sie es erneut."
            else
                break  # Gültige Auswahl und E-Mail-Adresse, Schleife verlassen
            fi
        elif [[ "$send_emails" == "n" || "$send_emails" == "N" ]]; then
            break  # Der Benutzer möchte keine E-Mails senden, Schleife verlassen
        else
            echo -e "\nUngültige Eingabe. Bitte geben Sie 'y' oder 'n' ein."
        fi
    done

    # Ausgabe der Variablen
    echo -e "\nQuell-Pool: $SOURCE_POOL"
    echo "Ziel-Pool: $DEST_POOL"
    echo "Log-Verzeichnis: $TEMP_LOG_DIR"
    echo "Pfad zur Log-Datei für den letzten Snapshot: $LAST_SNAPSHOT"
    echo "Pfad zur Log-Datei für gelöschte Snapshots: $DESTROYED_LOG"
    echo "Pfad zur Log-Datei für Snapshot-Checks: $SNAPCHECK"
    echo "Lebenszeit der Quellpool-Snapshots: $SOURCE_SNAP_LIFETIME"
    echo "Lebenszeit der Zielpool-Snapshots: $DEST_SNAP_LIFETIME"

    # Ausgabe der E-Mail-Adresse, Wenn diese definiert wurde
    if [[ -n "$TEMP_EMAIL_ADDRESS" ]]; then
        echo "E-Mail-Adresse: $TEMP_EMAIL_ADDRESS"
    fi

    # Bestätigen der Eingaben
    echo
    read -p "Sind die eingegebenen Werte korrekt? (y/n): " confirmation

    if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
        echo -e "\nDie eingegebenen Werte sind nicht korrekt. Das Skript wird von vorne gestartet.\n"
        echo $CONFIG_DIR
        rm -rf "$CONFIG_DIR"
        exec "$0" "$@" # Starte das Skript neu mit den ursprünglichen Argumenten
    fi

    # Lösche altes Config-Verzeichnis
    if [ -d "$LOG_DIR" ]; then
    rm -rf "$LOG_DIR"
    fi

    # Schreibe die Konfigurationswerte in die Konfigurationsdatei
    touch "$CONFIG_FILE"  # Erstellt die Config-Datei
    echo "SOURCE_POOL=\"$SOURCE_POOL\"" > "$CONFIG_FILE"
    echo "DEST_POOL=\"$DEST_POOL\"" >> "$CONFIG_FILE"
    echo "LOG_DIR=\"$TEMP_LOG_DIR\"" >> "$CONFIG_FILE"
    echo "LAST_SNAPSHOT=\"$LAST_SNAPSHOT\"" >> "$CONFIG_FILE"
    echo "DESTROYED_LOG=\"$DESTROYED_LOG\"" >> "$CONFIG_FILE"
    echo "SNAPCHECK=\"$SNAPCHECK\"" >> "$CONFIG_FILE"
    echo "SOURCE_SNAP_LIFETIME=\"$SOURCE_SNAP_LIFETIME\"" >> "$CONFIG_FILE"
    echo "DEST_SNAP_LIFETIME=\"$DEST_SNAP_LIFETIME\"" >> "$CONFIG_FILE"
    if [[ -n "$TEMP_EMAIL_ADDRESS" ]]; then
        echo "EMAIL_ADDRESS=\"$TEMP_EMAIL_ADDRESS\"" >> "$CONFIG_FILE"
    fi

    # Erstelle Log-Verzeichnis
    mkdir -p "$TEMP_LOG_DIR"
    if [ $? -eq 0 ]; then
        echo -e "\nLog-Verzeichnis wurde erfolgreich erstellt."
    else
        echo "Fehler beim Erstellen des Log-Verzeichnisses. Das Skript wird abgebrochen."
        exit 2
    fi

    # Prüfen, ob das Paket "zfs-prune-snapshots" installiert ist
    if [ ! -f "$FIRST_RUN_FLAG" ]; then
        if ! command -v zfs-prune-snapshots &>/dev/null; then
            echo "Das Paket 'zfs-prune-snapshots' ist nicht installiert."

            # Frage, ob das Paket über Git installiert werden soll
            read -p "Möchten Sie das Paket 'zfs-prune-snapshots' über Git installieren? (y/n): " install_choice

            if [[ $install_choice == "y" || $install_choice == "Y" ]]; then
                # Prüfe, ob Git installiert ist
                if ! command -v git &>/dev/null; then
                    echo "Git ist nicht installiert. Installiere Git..."

                if [ $(id -u) -eq 0 ]; then
                    # Als Root-Benutzer ausführen
                    install_with_apt() {
                        apt-get update
                        apt-get install -y git
                    }
                
                    install_with_dnf() {
                        dnf install -y git
                    }
                
                    install_with_yum() {
                        yum install -y git
                    }
                
                    install_with_pkg() {
                        pkg install -y git
                    }
                else
                    # Als nicht-Root-Benutzer ausführen (mit sudo)
                    install_with_apt() {
                        sudo apt-get update
                        sudo apt-get install -y git
                    }
                
                    install_with_dnf() {
                        sudo dnf install -y git
                    }
                
                    install_with_yum() {
                        sudo yum install -y git
                    }
                
                    install_with_pkg() {
                        sudo pkg install -y git
                    }
                fi

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
                        exit 3
                    fi
                fi
            fi

            # Definiere das absolute Verzeichnis
            absolute_dir="/opt/zfs-prune-snapshots"

            # Klone das Git-Repo
            git clone https://github.com/bahamas10/zfs-prune-snapshots.git "$absolute_dir"

            # Kopiere die Datei in /usr/bin/
            [ $(id -u) -eq 0 ] && {
                cp -r "$absolute_dir/zfs-prune-snapshots" /usr/bin/
            } || {
                sudo cp -r "$absolute_dir/zfs-prune-snapshots" /usr/bin/
            }

            # Prüfe, ob das Kommando nun verfügbar ist
            if command -v zfs-prune-snapshots &>/dev/null; then
                echo -e "\nDas Paket 'zfs-prune-snapshots' wurde erfolgreich installiert und ist nun verfügbar.\n\nfahre fort...\n"
            else
                echo -e "\nDas Paket 'zfs-prune-snapshots' konnte nicht erfolgreich installiert werden.\n\nBitte versuchen Sie Problem zu beheben oder das Paket manuell zu installieren.\n"
                exit 4
            fi
        fi
    fi
    if [ ! -f "$FIRST_RUN_FLAG" ]; then
    touch "$FIRST_RUN_FLAG"
    fi
fi

# Initialisieren der Variable, um den Status des ersten Snapshots zu verfolgen
first_snapshot=true

# Prüfen, ob bereits Snapshots im Quellpool vorhanden sind um das neue inkrementelle Snapshot daran anzuknüpfen
if [ "$(zfs list -t snapshot | grep "$DEST_POOL")" != "" ]; then

    # Ein vorheriger Snapshot wurde gefunden und wird in die Variable "last_sent_snapshot" eingelesen
    first_snapshot=false
    last_sent_snapshot=$(zfs list -t snapshot -o name,creation -s creation | grep "$SOURCE_POOL" | tail -n 1 | awk '{print $1}')
    echo -e "\nEin inkrementeller Snapshot wird erstellt.\n"
else

    # Es wurde kein vorheriger Snapshot gefunden, daher handelt es sich um den ersten Snapshot
    first_snapshot=true
    echo -e "\nEin vollständiger Snapshot wird erstellt."
fi

# Setze loop_condition auf true, um die Schleife mindestens einmal auszuführen
loop_condition=true

while [ "$loop_condition" = true ]; do
    # Prüfen, ob es der erste Snapshot ist und entsprechend handeln
    if [ "$first_snapshot" = true ]; then

    # Ein vollständiger Snapshot, einschließlich aller Sub-Datasets, wird für den Quellpool erstellt, dessen Name das aktuelle Datum und die Uhrzeit enthält
    full_snapshot="$SOURCE_POOL@fullsnapshot_$(date +%d-%m-%Y_%H:%M:%S)"
    zfs snapshot -r "$full_snapshot"

    # Senden des gesamten Snapshots, wenn es sich um den ersten Snapshot handelt
    zfs send -R "$full_snapshot" | zfs receive "$DEST_POOL" -F

    echo "$full_snapshot" > "$LAST_SNAPSHOT"
    # Ausgabe aller Snapshots
    echo
    zfs list -t snapshot
    echo
    loop_condition=false  # Setze loop_condition auf false, um die Schleife zu beenden

    else

        # Ein neuer inkrementeller Snapshot, einschließlich aller Sub-Datasets, wird für den Quellpool erstellt, dessen Name das aktuelle Datum und die Uhrzeit enthält
        new_snapshot="$SOURCE_POOL@incremental_snapshot_$(date +%d-%m-%Y_%H:%M:%S)"
        zfs snapshot -r "$new_snapshot"

        # Senden der inkrementellen Snapshots an den Zielpool, wenn Snapshots vorhanden sind
        send_output=$(zfs send -R -i "$last_sent_snapshot" "$new_snapshot" | zfs receive "$DEST_POOL" -F 2>&1)

        if [[ "$send_output" == *"cannot receive incremental stream: most recent snapshot of mybackup does not match incremental source"* ]]; then
            echo -e "\nFehler: Die letzten Snapshots stimmen nicht überein.\n"

            # Frage den Benutzer, ob alle Snapshots im Ziel-Pool gelöscht werden sollen
            read -p "Möchten Sie alle Snapshots im Ziel-Pool löschen und einen neuen vollständigen Snapshot erstellen? (y/n): " delete_and_create

            if [[ "$delete_and_create" == "y" || "$delete_and_create" == "Y" ]]; then
                # Lösche alle Snapshots im Ziel-Pool
                zfs list -r -H -t snapshot -o name "$DEST_POOL" | xargs -n1 zfs destroy
                echo "Alle Snapshots im Ziel-Pool wurden gelöscht, und ein neuer vollständiger Snapshot wird erstellt."
            else
            exit 5
            fi

            first_snapshot=true  # Setze first_snapshot auf true
            continue  # Springe zur Anfangsstelle der Schleife zurück
        else
            loop_condition=false  # Setze loop_condition auf false, um die Schleife zu beenden
        fi
    fi
done

# Der Name des neuen Snapshots wird in der Datei "zfs-last-snapshot.md" gespeichert
echo "$last_sent_snapshot" > "$LAST_SNAPSHOT"

# Der Name und Erstellungsdatum des aktuellsten Snapshots im Ziel-Pool wird in die Datei "zfs-snapcheck.log" geschrieben
zfs list -t snapshot -o name,creation -s creation | grep "$DEST_POOL" | tail -n 1 > "$SNAPCHECK"

# Auslesen des Namens des aktuellsten Snapshots aus der Datei "zfs-snapcheck.log"
SNAPCHECK_OUTPUT=$(cat "$SNAPCHECK")

# Nachricht an die Komandozeile
echo -e "\nalle snapshots wurden erfolgreich erstellt und an den Zielpool gesendet.\n\nletzter gesendeter Snapshot:\n"$SNAPCHECK_OUTPUT""

# Eine E-Mail wird mit Informationen über erfolgreich gesendete Snapshots und dem Namen 
# des letzten gesendeten Snapshots gesendet, wenn eine E-Mail-Adresse definiert wurde.
if [[ -n "$EMAIL_ADDRESS" ]]; then
    if [ "$first_snapshot" = true ]; then
        snapshot_list=$(zfs list -t snapshot)
        printf '%s\n' 'ein vollständiger zfs-snapshot wurde erfolgreich erstellt und übertragen:' "$snapshot_list" | mail -s "Zfs Send INFO" "$EMAIL_ADDRESS\n"
    else
        printf '%s\n' 'alle zfs-snapshots wurden erfolgreich erstellt und übertragen' 'letzter gesendeter snaphot:' "$SNAPCHECK_OUTPUT" | mail -s "Zfs Send INFO" "$EMAIL_ADDRESS\n"
    fi
fi
# Lösche alle inkrementellen Snapshots im Quellpool älter als SOURCE_SNAP_LIFETIME
/usr/bin/zfs-prune-snapshots -i -p 'incremental_snapshot_' "$SOURCE_SNAP_LIFETIME" "$SOURCE_POOL" > "$DESTROYED_LOG"

# Lösche alle inkrementellen Snapshots im Zielpool älter als DEST_SNAP_LIFETIME
/usr/bin/zfs-prune-snapshots -i -p 'incremental_snapshot_' "$DEST_SNAP_LIFETIME" "$DEST_POOL" >> "$DESTROYED_LOG"
DESTROYED_OUTPUT=$(cat "$DESTROYED_LOG")

# Eine E-Mail wird mit Informationen über erfolgreich gesendete Snapshots und dem Namen 
# des letzten gesendeten Snapshots gesendet, wenn eine E-Mail-Adresse definiert wurde.
if [[ -n "$EMAIL_ADDRESS" ]]; then

    echo "$DESTROYED_OUTPUT" | mail -s "Zfs Snap-removal INFO" "$EMAIL_ADDRESS"
fi

# Nachricht an die Komandozeile
echo -e "\nGelöschte Snapshots:\n\n$DESTROYED_OUTPUT\n"

exit
