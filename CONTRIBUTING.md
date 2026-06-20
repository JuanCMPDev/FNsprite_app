# Contributing

Thanks for helping improve SpiritMatch.

## Local Checks

Run the relevant checks before opening a pull request:

```bash
npm run lint
npm run typecheck
npm run test
npm run build
```

Infrastructure checks require Docker:

```bash
./gate.sh 00 infra
```

## Secrets

Do not commit real secrets. Use `.env.example` for placeholder values only.
