#!/usr/bin/env bash
#
# codex-setup.sh — SETUP SCRIPT para un entorno de Codex cloud (fase con red).
#
# Instala y arranca Postgres y Redis NATIVOS (sin Docker) y prepara el proyecto,
# para que la fase del agente pueda correr `./gate.sh NN code` sin docker-in-docker.
#
# Cómo usarlo:
#   1. Pega este script como "setup script" del entorno en el panel de Codex cloud.
#   2. En las VARIABLES del entorno (no aquí) define:
#        DATABASE_URL = postgresql://spiritmatch:spiritmatch@localhost:5432/spiritmatch
#        REDIS_URL    = redis://localhost:6379
#      (las variables del entorno persisten también en la fase del agente).
#   3. Si alguna stage necesita instalar deps nuevas y la fase del agente está
#      OFFLINE, o habilitas internet para el agente, o las pre-instalas aquí abajo.
#
set -euo pipefail
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "==> Instalando Postgres y Redis nativos (Ubuntu/codex-universal)"
$SUDO apt-get update -y
$SUDO apt-get install -y postgresql postgresql-contrib redis-server curl

echo "==> Arrancando servicios como daemons (persisten en la fase del agente)"
$SUDO service postgresql start
redis-server --daemonize yes

echo "==> Creando rol y base de datos (idempotente)"
$SUDO -u postgres psql -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'spiritmatch') THEN
    CREATE ROLE spiritmatch LOGIN PASSWORD 'spiritmatch';
  END IF;
END $$;
SQL
$SUDO -u postgres createdb -O spiritmatch spiritmatch 2>/dev/null || echo "(la base ya existe)"

echo "==> Dependencias del proyecto"
if [ -f package-lock.json ]; then
  npm ci
elif [ -f package.json ]; then
  npm install
else
  echo "(package.json aun no existe; Stage 00 lo creara)"
fi

if [ -f package.json ]; then
  echo "==> Pre-instalando deps anticipadas"
  npm install --save next react react-dom @prisma/client zod next-auth ioredis discord.js || true
  npm install --save-dev prisma vitest @playwright/test @types/node eslint prettier typescript || true
else
  echo "==> Sin package.json: habilita internet del agente para Stage 00"
fi

echo "==> Prisma generate + migrate (si ya existe schema)"
if [ -f prisma/schema.prisma ]; then
  npx prisma generate
  npx prisma migrate deploy || npx prisma migrate dev --name init --skip-seed || true
fi

echo "==> Verificando conectividad de servicios"
pg_isready -h localhost -p 5432 || echo "⚠ Postgres no responde aún"
redis-cli ping || echo "⚠ Redis no responde aún"

echo "==> Setup completo. Servicios nativos arriba. En la fase del agente, usa:"
echo "    ./gate.sh <NN> code"
