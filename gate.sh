#!/usr/bin/env bash
#
# gate.sh — verificación por stage, separada en perfiles CODE e INFRA.
#
# Perfiles (por env GATE_PROFILE o 2º argumento):
#   code  -> lint, typecheck, unit, build, e2e @stage-NN.
#            NO requiere Docker. Requiere Postgres/Redis NATIVOS accesibles vía
#            DATABASE_URL / REDIS_URL. Este es el perfil que corre el agente de
#            Codex cloud (donde docker-in-docker no es viable).
#   infra -> validación de docker-compose + smoke `docker compose up` + /api/health.
#            Requiere Docker. Va en CI o en tu VPS, NUNCA en el agente de la nube.
#   all   -> ambos. Por defecto. Úsalo en local/VPS con Docker disponible.
#
# Uso: ./gate.sh <NN> [code|infra|all]
#
set -uo pipefail
STAGE="${1:?Uso: ./gate.sh <NN> [code|infra|all]}"
PROFILE="${2:-${GATE_PROFILE:-all}}"
fail=0
run() { echo "▶ $*"; if ! "$@"; then echo "✗ FALLO: $*"; fail=1; fi; }

run_code() {
  echo "--- perfil CODE (sin Docker; servicios nativos vía DATABASE_URL/REDIS_URL) ---"
  run npm run -s lint
  run npm run -s typecheck
  run npm run -s test -- --run "tests/stage-${STAGE}"
  run npm run -s build
  case "$STAGE" in
    00) run npm run -s test -- --run "tests/stage-00/health" ;;  # health handler vs Postgres nativo
    01) run npm run -s test:e2e -- --grep "@stage-01" ;;
    02) run npm run -s test:e2e -- --grep "@stage-02" ;;
    03) run npm run -s test:e2e -- --grep "@stage-03" ;;
    04) run npm run -s test:e2e -- --grep "@stage-04" ;;
    05) run npm run -s test:e2e -- --grep "@stage-05" ;;
    06) run npm run -s test:e2e -- --grep "@stage-06" ;;
    07) run npm run -s test:e2e -- --grep "@stage-07" ;;   # usa Redis nativo
    08) run npm run -s test:e2e -- --grep "@stage-08" ;;   # bot con cliente Discord mockeado
  esac
}

run_infra() {
  echo "--- perfil INFRA (requiere Docker) ---"
  run test -f docker-compose.yml
  run test -f Dockerfile
  run test -f .env.example
  run test -f LICENSE
  run docker compose config -q
  case "$STAGE" in
    00|07|08)
      # smoke: levanta el stack completo y verifica health (07 suma redis, 08 suma bot)
      run bash -c 'docker compose up -d && sleep 10 && curl -fsS http://localhost:3000/api/health >/dev/null; rc=$?; docker compose down -v; exit $rc'
      ;;
    *) echo "(sin smoke de Docker específico para la stage ${STAGE})" ;;
  esac
}

echo "=== GATE stage ${STAGE} · perfil ${PROFILE} ==="
case "$PROFILE" in
  code)  run_code ;;
  infra) run_infra ;;
  all)   run_code; run_infra ;;
  *) echo "Perfil inválido: ${PROFILE} (usa code|infra|all)"; exit 2 ;;
esac

if [[ "$fail" -eq 0 ]]; then echo "=== ✅ GATE ${STAGE}/${PROFILE} VERDE ==="; else echo "=== ❌ GATE ${STAGE}/${PROFILE} ROJO ==="; fi
exit "$fail"
