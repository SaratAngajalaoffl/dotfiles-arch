# ADR 0005: pi agent configured exclusively for anera custom provider

## Status
Accepted

## Context
The `aic` AI commit assistant supports two backends: `claude` (Claude Code CLI) and `pi`. Previously, pi's `settings.json` defaulted to Anthropic (`claude-opus-4-8`). The user now has a self-hosted model (`aneramodel`) exposed via an OpenAI-compatible endpoint, and wants to use pi as the dedicated agent for it.

## Decision
Pi is configured exclusively for the anera custom provider. Anthropic auth and model config are removed from pi entirely. The `claude` CLI remains the sole entry point for Anthropic models.

Pi's `~/.pi/agent/models.json` declares a single provider (`anera`) pointing to `$ANERA_BASE_URL` with `$PI_CUSTOM_API_KEY`, using the `openai-completions` API schema. `settings.json` sets `defaultProvider: "anera"` and `defaultModel: "aneramodel"`.

## Alternatives considered
- **Keep both providers in pi** — redundant with claude for Anthropic; adds unnecessary auth setup on new machines.
- **Use claude for the custom model** — claude does not support arbitrary OpenAI-compatible endpoints; pi's `--provider` flag is the right tool for this.
- **Single agent for everything** — the backends serve different roles (managed subscription vs. self-hosted); keeping them split avoids accidental cross-usage and makes cost attribution clear.
