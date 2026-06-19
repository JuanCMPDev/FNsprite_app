#!/usr/bin/env bash
# notify.sh — avisa al operador (stage completa / stuck / bloqueada).
# Configura UNA de estas vías por variable de entorno; si no, solo imprime.
#   DISCORD_WEBHOOK_URL  -> manda al canal de Discord
#   SLACK_WEBHOOK_URL    -> manda a Slack
# Uso: ./notify.sh "mensaje"
set -euo pipefail
MSG="${1:?mensaje requerido}"
echo "🔔 $MSG"
if [[ -n "${DISCORD_WEBHOOK_URL:-}" ]]; then
  curl -fsS -H 'Content-Type: application/json' \
    -d "$(printf '{"content": %s}' "$(printf '%s' "$MSG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')")" \
    "$DISCORD_WEBHOOK_URL" >/dev/null || true
elif [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
  curl -fsS -H 'Content-Type: application/json' \
    -d "$(printf '{"text": %s}' "$(printf '%s' "$MSG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')")" \
    "$SLACK_WEBHOOK_URL" >/dev/null || true
fi
