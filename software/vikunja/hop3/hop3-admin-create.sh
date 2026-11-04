set -eu
ADMIN_USER="${HOP3_ADMIN_USER:?admin user not injected}"
ADMIN_EMAIL="${HOP3_ADMIN_EMAIL:?admin email not injected}"
ADMIN_PASSWORD="${HOP3_ADMIN_PASSWORD:?admin password not injected}"
present() {
  ./vikunja user list 2>/dev/null \
    | awk -F'|' 'NF>=4 { gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3 }' \
    | grep -Fxq "$ADMIN_USER"
}
if present; then
  echo "Vikunja admin already exists: $ADMIN_USER"
else
  ./vikunja user create -u "$ADMIN_USER" -e "$ADMIN_EMAIL" -p "$ADMIN_PASSWORD"
fi
present || { echo "ERROR: Vikunja admin '$ADMIN_USER' was not created" >&2; exit 1; }
