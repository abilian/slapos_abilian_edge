set -e
: "${HOP3_ADMIN_USER:?admin bootstrap: HOP3_ADMIN_USER not injected}"
: "${HOP3_ADMIN_EMAIL:?admin bootstrap: HOP3_ADMIN_EMAIL not injected (set [admin].email)}"
: "${HOP3_ADMIN_PASSWORD:?admin bootstrap: HOP3_ADMIN_PASSWORD not injected}"
sock="$(pwd)/mattermost_local.socket"
export MMCTL_LOCAL_SOCKET_PATH="$sock"
i=0
while [ ! -S "$sock" ]; do
  i=$((i + 1))
  if [ "$i" -gt 60 ]; then
    echo "Mattermost local-mode socket $sock never appeared (120s); cannot create admin" >&2
    exit 1
  fi
  sleep 2
done
if ./bin/mmctl --local user list --all | grep -Fq ": $HOP3_ADMIN_USER ("; then
  echo "Admin user '$HOP3_ADMIN_USER' already exists; skipping creation."
else
  ./bin/mmctl --local user create --system-admin --email-verified \
    --email "$HOP3_ADMIN_EMAIL" \
    --username "$HOP3_ADMIN_USER" \
    --password "$HOP3_ADMIN_PASSWORD"
fi
