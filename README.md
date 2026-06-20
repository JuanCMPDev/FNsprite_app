# SpiritMatch

Open-source web app scaffold for a trading-board style project.

This repository is under active development. Public documentation will be expanded as
the implementation stabilizes.

## Development

Install dependencies:

```bash
npm install
```

Set local environment values:

```bash
cp .env.example .env
```

Run code checks:

```bash
npm run lint
npm run typecheck
npm run test
npm run build
```

## Docker

Run the local stack:

```bash
docker compose up -d
```

The app is available at `http://localhost:3000`. Health checks are exposed at:

```bash
curl http://localhost:3000/api/health
```

Stop the stack:

```bash
docker compose down -v
```

## Gates

The project uses automated gates for code and infrastructure checks:

```bash
./gate.sh 00 code
./gate.sh 00 infra
```

Infrastructure checks require Docker and should be run only in an environment prepared
for that purpose.
