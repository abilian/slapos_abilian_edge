set -e
ADMIN_USER="${HOP3_ADMIN_USER:?admin user not injected}"
ADMIN_EMAIL="${HOP3_ADMIN_EMAIL:?admin email not injected}"
ADMIN_PASSWORD="${HOP3_ADMIN_PASSWORD:?admin password not injected}"
export GITEA_WORK_DIR="$(pwd)"
conf="custom/conf/app.ini"
present() { ./forgejo admin user list -c "$conf" | awk 'NR>1{print $2}' | grep -Fxq "$ADMIN_USER"; }
if present; then
  echo "Forgejo admin already exists: $ADMIN_USER"
else
  ./forgejo admin user create --admin --username "$ADMIN_USER" \
    --email "$ADMIN_EMAIL" --password "$ADMIN_PASSWORD" \
    --must-change-password=false -c "$conf"
fi
present || { echo "ERROR: Forgejo admin '$ADMIN_USER' was not created" >&2; exit 1; }
