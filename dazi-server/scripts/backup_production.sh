#!/usr/bin/env bash
set -euo pipefail
umask 077

APP_DIR=${DAZI_APP_DIR:-/opt/dazi-server}
BACKUP_DIR=${DAZI_BACKUP_DIR:-/opt/dazi-backups/encrypted}
KEY_FILE=${DAZI_BACKUP_KEY_FILE:-/opt/dazi-secrets/backup-passphrase}
RETENTION_DAYS=${DAZI_BACKUP_RETENTION_DAYS:-14}
COMPOSE=(docker compose --project-directory "$APP_DIR" -f "$APP_DIR/docker-compose.prod.yml")

[[ -s "$KEY_FILE" ]] || { echo "Backup encryption key is missing" >&2; exit 1; }
[[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] && (( RETENTION_DAYS >= 7 )) || exit 1
mkdir -p "$BACKUP_DIR"
exec 9>"$BACKUP_DIR/.backup.lock"
flock -n 9 || { echo "A backup is already running"; exit 0; }

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
WORK=$(mktemp -d "$BACKUP_DIR/.work.XXXXXXXX")
PARTIAL="$BACKUP_DIR/.dazi-$STAMP.tar.gpg.partial"
trap 'rm -rf -- "$WORK"; rm -f -- "$PARTIAL"' EXIT
mkdir -p "$WORK/uploads"

# Keep the union around the DB snapshot; restore verification rejects missing
# references if concurrent media changes still leave an incomplete snapshot.
if [[ -d "$APP_DIR/uploads" ]]; then
    rsync -a "$APP_DIR/uploads/" "$WORK/uploads/"
fi
"${COMPOSE[@]}" exec -T --interactive=false db pg_dump -U dazi -d dazi -Fc > "$WORK/database.dump"
if [[ -d "$APP_DIR/uploads" ]]; then
    rsync -a "$APP_DIR/uploads/" "$WORK/uploads/"
fi
tar -C "$WORK" -czf "$WORK/uploads.tar.gz" uploads
REVISION=$("${COMPOSE[@]}" exec -T --interactive=false db psql -U dazi -d dazi -Atc 'SELECT version_num FROM alembic_version')
python3 -c 'import json,sys; json.dump({"created_at":sys.argv[1],"revision":sys.argv[2]},sys.stdout)' \
    "$STAMP" "$REVISION" > "$WORK/metadata.json"
(
    cd "$WORK"
    sha256sum database.dump uploads.tar.gz metadata.json > SHA256SUMS
)
tar -C "$WORK" -cf - database.dump uploads.tar.gz metadata.json SHA256SUMS | \
    gpg --batch --yes --pinentry-mode loopback --no-symkey-cache \
        --passphrase-file "$KEY_FILE" --symmetric --cipher-algo AES256 \
        --compress-algo none --output "$PARTIAL"

DAZI_APP_DIR="$APP_DIR" DAZI_BACKUP_KEY_FILE="$KEY_FILE" \
    bash "$APP_DIR/scripts/verify_production_backup.sh" "$PARTIAL"
FINAL="$BACKUP_DIR/dazi-$STAMP.tar.gpg"
mv -- "$PARTIAL" "$FINAL"
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'dazi-*.tar.gpg' -mtime "+$RETENTION_DAYS" -delete
printf '[ok] encrypted and restore-verified backup: %s\n' "$FINAL"
