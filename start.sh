#!/busybox/busybox sh
# Start script for Wakapi on Railway.
#  1. waits for PostgreSQL on the private network,
#  2. on an empty database, creates the admin account from WAKAPI_ADMIN_USERNAME /
#     WAKAPI_ADMIN_PASSWORD through a loopback-only instance (Wakapi makes the first
#     registered user its admin, so the public URL never offers that to a stranger),
#  3. execs Wakapi on $PORT. Any failure exits non-zero so Railway restarts the service.
set -eu
B=/busybox/busybox
log() { echo "[start] $*"; }
die() { echo "[start] ERROR: $*" >&2; exit 1; }

# ---- settings with safe defaults ----
export ENVIRONMENT="${ENVIRONMENT:-prod}"
export WAKAPI_PORT="${PORT:-3000}"
export WAKAPI_LISTEN_IPV4="${WAKAPI_LISTEN_IPV4:-0.0.0.0}"
export WAKAPI_LISTEN_IPV6="${WAKAPI_LISTEN_IPV6:-::}"
export WAKAPI_DB_TYPE="${WAKAPI_DB_TYPE:-postgres}"
export WAKAPI_DB_PORT="${WAKAPI_DB_PORT:-5432}"
export WAKAPI_DB_SSL="${WAKAPI_DB_SSL:-false}"
export WAKAPI_DB_MAX_CONNECTIONS="${WAKAPI_DB_MAX_CONNECTIONS:-10}"
export WAKAPI_INSECURE_COOKIES="${WAKAPI_INSECURE_COOKIES:-false}"
export WAKAPI_ALLOW_SIGNUP="${WAKAPI_ALLOW_SIGNUP:-false}"
export WAKAPI_DISABLE_FRONTPAGE="${WAKAPI_DISABLE_FRONTPAGE:-false}"
# Railway's edge proxy reaches the app from these ranges; trusting them lets Wakapi rate-limit
# logins per visitor (X-Forwarded-For) instead of per proxy.
export WAKAPI_TRUST_REVERSE_PROXY_IPS="${WAKAPI_TRUST_REVERSE_PROXY_IPS:-100.64.0.0/10,fd00::/8}"

[ -n "${WAKAPI_PASSWORD_SALT:-}" ] || die "WAKAPI_PASSWORD_SALT is empty"
[ "$WAKAPI_DB_TYPE" = sqlite3 ] || [ -n "${WAKAPI_DB_HOST:-}" ] || die "WAKAPI_DB_HOST is empty (is the Postgres service there?)"

# ---- fit the container: Go sees every host CPU, not the service's share ----
CPUS=2
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read q p < /sys/fs/cgroup/cpu.max || true
  if [ "${q:-max}" != max ] && [ "${p:-0}" -gt 0 ]; then CPUS=$(( (q + p - 1) / p )); fi
fi
[ "$CPUS" -ge 1 ] || CPUS=1; [ "$CPUS" -le 4 ] || CPUS=4
export GOMAXPROCS="${GOMAXPROCS:-$CPUS}"
if [ -z "${GOMEMLIMIT:-}" ] && [ -r /sys/fs/cgroup/memory.max ]; then
  m=$($B cat /sys/fs/cgroup/memory.max)
  if [ "$m" != max ]; then export GOMEMLIMIT="$(( m / 1048576 * 80 / 100 ))MiB"; fi
fi
log "GOMAXPROCS=$GOMAXPROCS GOMEMLIMIT=${GOMEMLIMIT:-unset}"

cd /app

# ---- wait for the database (private DNS can take a minute on a first deploy) ----
if [ "$WAKAPI_DB_TYPE" != sqlite3 ]; then
  i=0
  until $B nc -z -w 3 "$WAKAPI_DB_HOST" "$WAKAPI_DB_PORT" 2>/dev/null; do
    i=$((i + 1)); [ "$i" -lt 60 ] || die "database ${WAKAPI_DB_HOST}:${WAKAPI_DB_PORT} unreachable after 3 minutes"
    [ $((i % 5)) -ne 1 ] || log "waiting for database ${WAKAPI_DB_HOST}:${WAKAPI_DB_PORT}"
    $B sleep 3
  done
  log "database is reachable"
fi

# ---- first boot: create the admin on an empty database ----
urlenc() { printf '%s' "$1" | $B od -An -tx1 -v | $B tr -d ' \n' | $B sed 's/\(..\)/%\1/g'; }
seed_admin() {
  SP=34567; U="http://127.0.0.1:$SP"
  WAKAPI_PORT=$SP WAKAPI_LISTEN_IPV4=127.0.0.1 WAKAPI_LISTEN_IPV6=- WAKAPI_ALLOW_SIGNUP=true \
  WAKAPI_QUICK_START=true WAKAPI_WARM_CACHES=false WAKAPI_INSECURE_COOKIES=true \
  WAKAPI_SIGNUP_CAPTCHA=false WAKAPI_DISABLE_LOCAL_AUTH=false \
    /app/wakapi > /tmp/seed.log 2>&1 &
  pid=$!
  i=0
  until $B wget -q -T 3 -O /dev/null "$U/api/health" 2>/dev/null; do
    if ! kill -0 "$pid" 2>/dev/null; then $B tail -n 40 /tmp/seed.log >&2; die "Wakapi exited during first-boot setup"; fi
    i=$((i + 1)); [ "$i" -lt 300 ] || { kill "$pid"; die "Wakapi did not answer on loopback within 5 minutes"; }
    $B sleep 1
  done
  if $B wget -q -T 20 -O - "$U/signup" | $B grep -q "no users registered"; then
    [ -n "${WAKAPI_ADMIN_USERNAME:-}" ] || { kill "$pid"; die "WAKAPI_ADMIN_USERNAME is empty"; }
    AP="${WAKAPI_ADMIN_PASSWORD:-}"
    [ "${#AP}" -ge 6 ] || { kill "$pid"; die "WAKAPI_ADMIN_PASSWORD must have at least 6 characters"; }
    log "empty database: creating admin '${WAKAPI_ADMIN_USERNAME}'"
    pw=$(urlenc "$AP")
    $B wget -q -T 60 -O /dev/null \
      --post-data "username=$(urlenc "$WAKAPI_ADMIN_USERNAME")&email=&password=$pw&password_repeat=$pw" \
      "$U/signup" 2>/dev/null || true
    if $B wget -q -T 20 -O - "$U/signup" | $B grep -q "no users registered"; then
      kill "$pid"; $B tail -n 40 /tmp/seed.log >&2; die "could not create the admin account"
    fi
    log "admin '${WAKAPI_ADMIN_USERNAME}' created"
  else
    log "users already exist: skipping admin setup"
  fi
  kill "$pid" 2>/dev/null || true
  i=0; while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 30 ]; do $B sleep 1; i=$((i + 1)); done
  kill -9 "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}
seed_admin

log "starting Wakapi on port $WAKAPI_PORT"
exec /app/wakapi
