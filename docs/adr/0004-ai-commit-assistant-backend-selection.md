# ADR 0004: AI commit assistant — runtime backend selection over per-repo config

## Status
Accepted

## Context
We want a shell function (`aic`) that generates Conventional Commits messages for staged changes using an AI CLI. Two backends are available: `claude` (Claude Code CLI, subscription-based) and `pi` (supports custom providers and models via `--provider`/`--model` flags). Different repos benefit from different backends — some warrant a more capable model, others are fine with whatever is cheapest.

## Decision
`claude` is the default backend. To use a different backend, pass `--agent <name>` at invocation (e.g. `aic --agent pi`). Both `claude` and `pi` are supported values. No prompt is shown when no flag is given.

## lazygit integration

`aic` exposes a `--generate` flag: when passed, it prints the commit message to stdout and exits 0 with no user interaction. This is consumed by lazygit's `menuFromCommand` prompt type, which runs `aic --generate`, presents the output as a selectable menu item, then hands off to an `input` prompt pre-filled with the chosen message for final editing before committing. The `filter`/`valueFormat`/`labelFormat` fields on `menuFromCommand` are intentionally omitted — lazygit uses each output line as-is, which is sufficient since `aic --generate` emits exactly one line.

`suspend: true` was explicitly rejected for this integration: lazygit does not wire stdin as a TTY for suspended commands, so `read` calls and interactive editors silently fail or produce no output.

## Alternatives considered
- **Per-repo git config** (`git config claude.model`) — cleaner for automation but adds friction: you must remember to set it on every new repo, and it leaks into `.git/config` which isn't version-controlled. Ruled out because the user explicitly wanted to avoid repo-level config.
- **Environment variable** — a single global default, no per-repo flexibility. Ruled out because backend choice genuinely varies by repo and context, not just by machine.
- **Interactive prompt on every invocation** — the original approach; eliminated because claude is the right choice the vast majority of the time and the prompt adds unnecessary friction.
