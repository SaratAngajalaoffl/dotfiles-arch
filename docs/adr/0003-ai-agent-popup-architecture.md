# ADR 0003: AI agent popup — persistent terminal buffers with lazy init

## Status
Accepted

## Context
We want a lazygit-style floating popup (`<C-S-L>`) that hosts two AI agent CLIs (`claude` and `pi`) in switchable tabs. The agents need to survive popup close so sessions aren't lost between editor interactions.

## Decision
Each agent is backed by a persistent Neovim terminal buffer that is never killed when the popup closes. The floating window is created on demand and reuses whichever buffer is active. Buffers are spawned lazily — only when an agent's tab is first focused — to avoid startup overhead in sessions that never use the popup. If a buffer's job has exited (crash or intentional `exit`), it is respawned automatically the next time its tab is focused.

Tab switching inside the popup uses `<C-k>` (not bare `<Tab>`) because the popup is a terminal buffer and bare `<Tab>` would be sent to the running process. The toggle key `<C-S-L>` is mapped in both normal mode (global) and terminal mode (per-buffer) so the popup can be dismissed from either mode.

## Alternatives considered
- **Kill on close** — simpler state management but destroys agent context on every popup dismiss, which is the main thing we're trying to avoid.
- **Eager init at Neovim startup** — agents are warm immediately but adds process startup cost and network connections to every Neovim launch, even sessions that never open the popup.
- **Snacks.terminal wrapper** — would handle the float chrome but doesn't support tab-switching between two persistent terminal buffers without custom state management anyway; building directly on `nvim_open_win` is the same amount of code with no extra dependency.
