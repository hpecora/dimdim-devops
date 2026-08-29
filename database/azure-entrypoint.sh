#!/bin/bash
set -e

BACKUP_DIR="/backup"
BACKUP_FILE="$BACKUP_DIR/clientes-data.sql"
RESTORE_FILE="/docker-entrypoint-initdb.d/02-restore-data.sql"

mkdir -p "$BACKUP_DIR"

echo "Verificando backup persistente..."

if [ -s "$BACKUP_FILE" ]; then
    echo "Backup encontrado. Preparando restauracao..."
    cp "$BACKUP_FILE" "$RESTORE_FILE"
else
    echo "Nenhum backup anterior encontrado."
    rm -f "$RESTORE_FILE"
fi

docker-entrypoint.sh "$@" &
POSTGRES_PID=$!

echo "Aguardando PostgreSQL iniciar..."

for i in $(seq 1 60); do

    if pg_isready \
        -U "${POSTGRES_USER:-postgres}" \
        -d "${POSTGRES_DB:-postgres}" \
        >/dev/null 2>&1; then

        echo "PostgreSQL esta pronto."
        break
    fi

    if ! kill -0 "$POSTGRES_PID" 2>/dev/null; then
        wait "$POSTGRES_PID"
        exit $?
    fi

    sleep 2
done

backup_database() {

    if pg_isready \
        -U "${POSTGRES_USER:-postgres}" \
        -d "${POSTGRES_DB:-postgres}" \
        >/dev/null 2>&1; then

        echo "Salvando backup no Azure Files..."

        pg_dump \
            -U "${POSTGRES_USER:-postgres}" \
            -d "${POSTGRES_DB:-postgres}" \
            --data-only \
            --inserts \
            --table=clientes \
            > "$BACKUP_FILE.tmp"

        mv "$BACKUP_FILE.tmp" "$BACKUP_FILE"

        echo "Backup atualizado."
    fi
}

(
    while kill -0 "$POSTGRES_PID" 2>/dev/null; do
        sleep 10
        backup_database || true
    done
) &

BACKUP_PID=$!

trap '
    backup_database || true
    kill -TERM "$POSTGRES_PID" 2>/dev/null || true
    wait "$POSTGRES_PID" || true
    exit 0
' TERM INT

wait "$POSTGRES_PID"
STATUS=$?

kill "$BACKUP_PID" 2>/dev/null || true

exit "$STATUS"