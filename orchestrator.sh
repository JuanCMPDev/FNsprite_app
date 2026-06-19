#!/usr/bin/env bash
#
# orchestrator.sh — corre UNA stage en loop hasta que su gate pase (verde) o se agoten
# las iteraciones (stuck). Diseñado para correr SIN supervisión, dentro de un sandbox.
#
# Uso:   ./orchestrator.sh <NN>          # ej: ./orchestrator.sh 03
# Salida: 0 = stage verde · 10 = stuck (necesita humano) · otro = error
#
# ⚠ IMPORTANTE
#  - Corre esto en un CONTENEDOR/VM dedicado, nunca en tu máquina principal.
#  - Verifica los nombres de flags con `codex exec --help` o `claude --help`.
#  - El uso headless puede facturarse distinto al interactivo: revisa tu pricing.
#
set -euo pipefail

STAGE="${1:?Uso: ./orchestrator.sh <NN>  (ej. 03)}"
TASK_FILE="tasks/stage-${STAGE}.md"
GATE="./gate.sh"
GATE_PROFILE="${GATE_PROFILE:-all}"    # code|infra|all; Codex cloud usa code sin Docker
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/stage-${STAGE}.log"

# ---- Topes de seguridad (ajustables por entorno) -------------------------------
MAX_ITERS="${MAX_ITERS:-12}"          # máximo de vueltas del loop por stage
MAX_TURNS="${MAX_TURNS:-40}"          # máximo de turnos del agente por invocación
CALL_TIMEOUT="${CALL_TIMEOUT:-1800}"  # timeout por invocación del agente (segundos)
MODEL="${MODEL:-}"                    # opcional: fija un modelo (ej. para abaratar)
AGENT="${AGENT:-codex}"               # codex|claude
INSTRUCTIONS_FILE="${INSTRUCTIONS_FILE:-}"

# ---- Allowlist de herramientas (sin skip-permissions) --------------------------
# Solo lo necesario para construir/probar. NADA de deploy ni de tocar secretos.
ALLOWED_TOOLS=(
  "Read" "Edit" "Write"
  "Bash(npm *)" "Bash(npx *)" "Bash(pnpm *)"
  "Bash(git add *)" "Bash(git commit *)" "Bash(git status *)" "Bash(git diff *)" "Bash(git log *)"
  "Bash(npx prisma *)"
  "Bash(docker compose build *)" "Bash(docker compose up -d *)" "Bash(docker compose down *)" "Bash(docker compose ps *)" "Bash(docker compose logs *)"
  "Bash(./gate.sh *)"
)

mkdir -p "$LOG_DIR"
[[ -f "$TASK_FILE" ]] || { echo "No existe $TASK_FILE"; exit 1; }

case "$AGENT" in
  codex) INSTRUCTIONS_FILE="${INSTRUCTIONS_FILE:-AGENTS.md}" ;;
  claude) INSTRUCTIONS_FILE="${INSTRUCTIONS_FILE:-CLAUDE.md}" ;;
  *) echo "AGENT inválido: $AGENT (usa codex|claude)"; exit 2 ;;
esac
[[ -f "$INSTRUCTIONS_FILE" ]] || { echo "No existe $INSTRUCTIONS_FILE"; exit 1; }

# ¿Esta stage requiere revisión humana al terminar?
HUMAN_REVIEW="$(grep -m1 -E '^HUMAN_REVIEW:' "$TASK_FILE" | awk '{print $2}' || echo "recommended")"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }

run_gate() {
  "$GATE" "$STAGE" "$GATE_PROFILE"
}

build_prompt() {
  local gate_output="$1"
  cat <<PROMPT
Estás trabajando en la stage ${STAGE} del proyecto SpiritMatch, SIN supervisión.

Lee primero ${INSTRUCTIONS_FILE} y ${TASK_FILE}. Respeta TODAS las reglas duras de ${INSTRUCTIONS_FILE}.

Estado actual del gate (${GATE} ${STAGE} ${GATE_PROFILE}):
---
${gate_output}
---

Tu objetivo en esta iteración:
1. Haz el MENOR progreso significativo para que pase el próximo check que falla.
2. Escribe primero los tests de verificación que la tarea exige, luego el código.
3. NO debilites tests para que pasen. NO toques secretos. NO hagas deploy.
4. Corre ${GATE} ${STAGE} ${GATE_PROFILE} tú mismo y arregla lo que rompas.
5. Commitea con mensaje convencional cuando algo pase.
6. Si te bloqueas por falta de info o de una decisión humana, escribe BLOCKER.md y detente.

No intentes la stage entera de un golpe. Una iteración = un avance verificable.
PROMPT
}

run_claude() {
  local prompt="$1"
  local -a cmd=( claude -p "$prompt" --output-format json --max-turns "$MAX_TURNS" )
  [[ -n "$MODEL" ]] && cmd+=( --model "$MODEL" )
  for t in "${ALLOWED_TOOLS[@]}"; do cmd+=( --allowedTools "$t" ); done
  # timeout protege contra cuelgues; tee guarda el log
  timeout "$CALL_TIMEOUT" "${cmd[@]}" 2>&1 | tee -a "$LOG_FILE"
  return "${PIPESTATUS[0]}"
}

run_codex() {
  local prompt="$1"
  local -a cmd=( codex exec --sandbox workspace-write -c 'approval_policy="never"' --json )
  [[ -n "$MODEL" ]] && cmd+=( --model "$MODEL" )
  cmd+=( "$prompt" )
  timeout "$CALL_TIMEOUT" "${cmd[@]}" 2>&1 | tee -a "$LOG_FILE"
  return "${PIPESTATUS[0]}"
}

run_agent() {
  local prompt="$1"
  case "$AGENT" in
    codex) run_codex "$prompt" ;;
    claude) run_claude "$prompt" ;;
  esac
}

log "=== Iniciando stage ${STAGE} (AGENT=${AGENT}, GATE_PROFILE=${GATE_PROFILE}, HUMAN_REVIEW=${HUMAN_REVIEW}, MAX_ITERS=${MAX_ITERS}) ==="

# ¿Ya está verde de entrada?
if gate_out="$(run_gate 2>&1)"; then
  log "Gate ya en verde antes de empezar."
else
  iter=0
  while (( iter < MAX_ITERS )); do
    iter=$((iter+1))
    log "--- Iteración ${iter}/${MAX_ITERS} ---"

    if ! run_agent "$(build_prompt "$gate_out")"; then
      log "${AGENT} salió con error (exit != 0). Reintentando con el mismo estado."
    fi

    if [[ -f BLOCKER.md ]]; then
      log "BLOCKER.md detectado. Deteniéndose para intervención humana."
      ./notify.sh "🚧 Stage ${STAGE} BLOQUEADA — revisa BLOCKER.md" || true
      exit 10
    fi

    if gate_out="$(run_gate 2>&1)"; then
      log "✅ Gate en VERDE en la iteración ${iter}."
      break
    else
      log "Gate sigue en rojo. Realimentando salida al agente."
    fi

    if (( iter == MAX_ITERS )); then
      log "⛔ Agotadas ${MAX_ITERS} iteraciones sin pasar el gate (STUCK)."
      ./notify.sh "⛔ Stage ${STAGE} STUCK tras ${MAX_ITERS} iteraciones — necesita un humano" || true
      exit 10
    fi
  done
fi

# Verde. ¿Necesita revisión humana antes de avanzar?
if [[ "$HUMAN_REVIEW" == "required" ]]; then
  log "🟡 Stage ${STAGE} VERDE pero requiere REVISIÓN HUMANA antes de continuar."
  ./notify.sh "🟡 Stage ${STAGE} lista para tu revisión (verde, gate humano)" || true
  exit 0
fi

log "🟢 Stage ${STAGE} COMPLETA."
./notify.sh "🟢 Stage ${STAGE} completa y en verde" || true
exit 0
