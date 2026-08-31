#!/usr/bin/env bash
set -euo pipefail
umask 077

APP_DIR=${DAZI_APP_DIR:-/opt/dazi-server}
KEY_FILE=${DAZI_BACKUP_KEY_FILE:-/opt/dazi-secrets/backup-passphrase}
ARCHIVE=${1:?Usage: verify_production_backup.sh ARCHIVE.tar.gpg}
COMPOSE=(docker compose --project-directory "$APP_DIR" -f "$APP_DIR/docker-compose.prod.yml")
WORK=$(mktemp -d /tmp/dazi-restore-check.XXXXXXXX)
DATABASE="dazi_restore_$(date +%s)_$$"
CREATED=0
cleanup() {
    local status=$?
    if [[ "$CREATED" == 1 ]]; then
        if ! "${COMPOSE[@]}" exec -T --interactive=false db dropdb -U dazi --if-exists "$DATABASE" >/dev/null; then
            echo "Temporary restore database cleanup failed" >&2
            status=1
        fi
    fi
    rm -rf -- "$WORK"
    return "$status"
}
trap cleanup EXIT

gpg --batch --pinentry-mode loopback --no-symkey-cache --passphrase-file "$KEY_FILE" \
    --decrypt "$ARCHIVE" | tar -C "$WORK" -xf - --no-same-owner \
    database.dump uploads.tar.gz metadata.json SHA256SUMS
(
    cd "$WORK"
    sha256sum -c SHA256SUMS
)
tar -C "$WORK" -xzf "$WORK/uploads.tar.gz" --no-same-owner
"${COMPOSE[@]}" exec -T --interactive=false db createdb -U dazi "$DATABASE"
CREATED=1
"${COMPOSE[@]}" exec -T db pg_restore -U dazi -d "$DATABASE" \
    --exit-on-error --no-owner --no-privileges < "$WORK/database.dump"
TABLE_COUNT=$("${COMPOSE[@]}" exec -T --interactive=false db psql -U dazi -d "$DATABASE" -Atc \
    "SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename <> 'alembic_version'")
(( TABLE_COUNT >= 27 )) || { echo "Restored schema is incomplete" >&2; exit 1; }
REVISION=$("${COMPOSE[@]}" exec -T --interactive=false db psql -U dazi -d "$DATABASE" -Atc 'SELECT version_num FROM alembic_version')
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["revision"] == sys.argv[2]' \
    "$WORK/metadata.json" "$REVISION"
"${COMPOSE[@]}" exec -T --interactive=false db psql -U dazi -d "$DATABASE" -Atc "
    SELECT COALESCE(json_agg(url), '[]'::json) FROM (
        SELECT avatar_url AS url FROM users WHERE avatar_url IS NOT NULL
        UNION ALL SELECT avatar_url AS url FROM agents WHERE avatar_url IS NOT NULL
        UNION ALL SELECT jsonb_array_elements_text(photo_urls) AS url FROM event_gallery_items
    ) AS media
" | python3 "$APP_DIR/scripts/verify_backup_media.py" "$WORK/uploads"
printf '[ok] restored %s business tables at revision %s; production database untouched\n' "$TABLE_COUNT" "$REVISION"
