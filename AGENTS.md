# AGENTS.md

This repository is intended to be built incrementally by Codex.

## Working Rules

- Follow the user's current task prompt as the source of scope.
- Prefer small, verifiable changes over broad rewrites.
- Write or update tests for behavior you change.
- Run the relevant gate before declaring work complete.
- Do not weaken tests to make a check pass.
- Do not read, print, create, or commit real secrets.
- Do not deploy production infrastructure or modify production services.
- Use environment variables for secrets and document placeholders only in examples.
- Keep commits focused and use conventional commit messages when committing.

## Expected Gate

Use:

```bash
./gate.sh <stage> code
```

Use the full Docker/infra profile only in an environment where Docker is intentionally
available.
