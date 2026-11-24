#!/bin/sh
# smoke.sh BASE_URL ADMIN_USER ADMIN_PASS API_KEY(optional)
U=$1; AU=$2; AP=$3; K=${4:-}
echo "health: $(curl -s $U/api/health | tr '\n' ' ')"
echo "signup page admin-warning (should be 0): $(curl -s $U/signup | grep -c 'no users registered')"
echo "stranger signup: $(curl -s -o /tmp/s.html -w '%{http_code}' --data 'username=evil&email=&password=evilpass&password_repeat=evilpass' $U/signup) $(grep -o 'registration is disabled[^<]*' /tmp/s.html | head -1)"
echo "bad login: $(curl -s -o /dev/null -w '%{http_code}' --data-urlencode username=$AU --data-urlencode password=wrongpw $U/login)"
rm -f /tmp/cj; echo "admin login: $(curl -s -c /tmp/cj -o /dev/null -w '%{http_code} %{redirect_url}' --data-urlencode username=$AU --data-urlencode "password=$AP" $U/login)"
echo "settings with cookie: $(curl -s -b /tmp/cj -o /tmp/set.html -w '%{http_code}' $U/settings)"
[ -z "$K" ] && K=$(grep -o '[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}' /tmp/set.html | head -1)
echo "api key found: ${K:+yes}"
B=$(printf '%s' "$K" | base64 | tr -d '\n')
NOW=$(date +%s)
for d in 600 480 360 240 120 0; do
 curl -s -o /dev/null -w '%{http_code} ' -H "Authorization: Basic $B" -H 'Content-Type: application/json' \
  -d "{\"entity\":\"/home/me/proj/main.go\",\"type\":\"file\",\"category\":\"coding\",\"time\":$((NOW-d)),\"project\":\"railway-test\",\"language\":\"Go\",\"is_write\":true}" $U/api/heartbeat
done; echo
echo "summary: $(curl -s -H "Authorization: Basic $B" "$U/api/summary?interval=today" | head -c 300)"
echo "wakatime compat: $(curl -s -H "Authorization: Basic $B" "$U/api/compat/wakatime/v1/users/current/all_time_since_today" | head -c 200)"
