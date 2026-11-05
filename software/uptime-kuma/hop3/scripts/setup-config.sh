#!/bin/bash
set -e
cd "$(dirname "$0")/.."

# Choose the database for Uptime Kuma, headlessly.
#
# Uptime Kuma 2.x runs a *database* setup wizard before the app itself starts:
# with no data/db-config.json it logs "Starting Setup Database ... Waiting for
# user action" and serves only that chooser. It never creates the schema, so the
# app never becomes usable and the ADR-056 admin bootstrap has no `user` table
# to write to. A deploy cannot click that wizard, so make the choice here.
#
# Seed-only: an operator who later switches this instance to MariaDB through the
# UI has their choice recorded in this same file, and a redeploy must not drag
# them back to SQLite.
DATA_DIR="${DATA_DIR:-./data/}"
mkdir -p "$DATA_DIR"

config="${DATA_DIR%/}/db-config.json"
if [ -f "$config" ]; then
    echo "Uptime Kuma: keeping the existing database config ($config)"
else
    # The format Database.readDBConfig expects (server/database.js); SQLite needs
    # no other keys, and its file lives beside this one on the same volume.
    printf '{\n    "type": "sqlite"\n}\n' > "$config"
    echo "Uptime Kuma: configured SQLite storage ($config)"
fi

# Migrate the schema and create the initial admin (ADR 056) BEFORE the server
# starts. Uptime Kuma decides "do I need setup?" once, at startup, by counting
# users; creating the account afterwards leaves that decision stale and the app
# keeps serving its setup wizard. Fail loud -- `set -e` aborts the deploy.
node scripts/create-admin.js
