#!/usr/bin/env bash
#
# run-all.sh — encadena las stages 00..08 corriendo orchestrator.sh en cada una.
# Se DETIENE en cualquier stage marcada HUMAN_REVIEW: required (o stuck), para que
# revises antes de continuar. Reanuda desde la stage que le pases.
#
# Uso:  ./run-all.sh            # desde la 00
#       ./run-all.sh 04         # reanuda desde la 04
#
set -euo pipefail
START="${1:-00}"
STAGES=(00 01 02 03 04 05 06 07 08)

started=0
for s in "${STAGES[@]}"; do
  [[ "$s" == "$START" ]] && started=1
  (( started )) || continue

  echo "######## STAGE ${s} ########"
  set +e
  ./orchestrator.sh "$s"
  rc=$?
  set -e

  if [[ $rc -eq 10 ]]; then
    echo "⏸  Detenido en stage ${s} (stuck o gate humano). Revisa, y reanuda con: ./run-all.sh ${s}"
    exit 0
  elif [[ $rc -ne 0 ]]; then
    echo "✗ Error en stage ${s} (rc=$rc). Abortando."
    exit $rc
  fi

  # Gate humano: orchestrator sale 0 pero la stage pide revisión -> paramos igual.
  hr="$(grep -m1 -E '^HUMAN_REVIEW:' "tasks/stage-${s}.md" | awk '{print $2}' || echo recommended)"
  if [[ "$hr" == "required" ]]; then
    echo "⏸  Stage ${s} verde pero requiere tu revisión. Aprueba el diff y reanuda con: ./run-all.sh $(printf '%02d' $((10#$s + 1)))"
    exit 0
  fi
done
echo "🎉 Todas las stages del MVP (00..08) completas."
