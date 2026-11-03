#!/bin/bash
# Radicale setup (ADR 056): re-template the config on every deploy so config
# changes always apply, and bootstrap the admin htpasswd entry from the
# credential Hop3 generated.
set -e
cd "$(dirname "$0")/.."

# The generated admin credential is required. A missing credential must abort
# the deploy loudly rather than silently produce a server nobody can log into
# (or, worse, fall back to anonymous access).
: "${HOP3_ADMIN_USER:?ERROR: HOP3_ADMIN_USER is required (see [admin] section, ADR 056)}"
: "${HOP3_ADMIN_PASSWORD:?ERROR: HOP3_ADMIN_PASSWORD is required (see [admin] section, ADR 056)}"

# Always (re)write the config so switching auth on redeploy takes effect. Auth
# is htpasswd/bcrypt: this closes the previous anonymous read/write to all data.
cat > config << EOF
[server]
hosts = 0.0.0.0:${PORT:-8080}

[auth]
type = htpasswd
htpasswd_filename = auth/users
htpasswd_encryption = bcrypt

[storage]
filesystem_folder = collections
EOF

# Write the admin's htpasswd entry from the injected credential, on every deploy,
# keeping every other entry: auth/ is a volume, so the file outlives the deploy,
# and an account added to it must too. The password is a stable generated
# secret; only the bcrypt salt changes. (bcrypt comes from radicale[bcrypt].)
mkdir -p auth
touch auth/users
python -c "
import bcrypt, os, pathlib
path = pathlib.Path('auth/users')
user = os.environ['HOP3_ADMIN_USER']
lines = [l for l in path.read_text().splitlines() if l and not l.startswith(user + ':')]
hashed = bcrypt.hashpw(os.environ['HOP3_ADMIN_PASSWORD'].encode(), bcrypt.gensalt()).decode()
path.write_text('\\n'.join([*lines, user + ':' + hashed]) + '\\n')
"

echo "Radicale configuration ready"
