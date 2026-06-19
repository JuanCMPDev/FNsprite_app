#!/usr/bin/env bash
# run-stage.sh — atajo para una sola stage. Uso: ./run-stage.sh 03
set -euo pipefail
exec ./orchestrator.sh "${1:?Uso: ./run-stage.sh <NN>}"
