# ADR 0006: aicp — one parallel AI-commit pass across submodules and the parent

## Status
Accepted

## Context
Config for one logical change routinely spans several app repos. Because each app repo is a submodule (see ADR 0001), each dirty submodule needs its own commit, and the parent then needs a commit of the resulting submodule bumps. The only tooling was `aic` (ADR 0004), which is strictly single-repo: the user had to run it once per dirty submodule and finally in the parent — a serial loop of a dozen AI calls, with each submodule's message reviewed in isolation.

Committing order matters and is not independent: the parent's diff is the submodule SHAs, so it can only be committed after the submodules are committed, and the AI-written parent message should describe the submodule commits it actually references.

## Decision
`bin/aicp` drives the whole thing as two sequential passes:

1. **Submodule pass** — every dirty submodule is staged (`git add -A`) and `aic --generate` runs for it, all concurrently. The messages appear all at once in a `whiptail` checklist, are dumped in full for reading, then the selected ones are opened together in `$EDITOR`. Each kept block is committed and pushed.
2. **Parent pass** — identical, with the parent repo as the only entry. By this point its diff is the bump SHAs, so the generated message describes them.

Bound to lazygit's `A` in the files panel with `output: terminal`.

Reconciling "generate, review, then commit" without a terminal-filling TUI: the review step is a *text* file — blocks of `---8<--- <repo>` followed by the message — opened in `$EDITOR`. Deleting a block drops that repo; emptying its body does too. That makes bulk review a single buffer, needs no editor features beyond multi-file text, and keeps the *whole* flow inside one `output: terminal` command rather than nesting an editor inside a lazygit prompt.

## Consequences
- Parallel generation is purely a latency win — the backend calls share no state, so ordering doesn't matter.
- Push is the default (it's what makes the parent's referenced SHAs real). `--no-push` covers local-only use.
- The checklist excludes submodules in a detached HEAD (default) state: publishing such a commit from the parent would move the parent's recorded submodule pin to a SHA that exists on no branch. Their blocks are dropped and the default is shown, so the skip is visible rather than silent.
- Passes are not atomic. If the parent pass is abandoned after the submodules were pushed, re-running `aicp` picks the parent up alone, and the already-committed submodules are skipped because they are no longer dirty.
- Requires a TTY and `whiptail` (`libnewt`, already pulled in by `networkmanager`) — hence lazygit must run it with `output: terminal`, never a prompt type.

## Alternatives considered
- **Pure lazygit prompts** (a chain of `menuFromCommand`/`input` like `aic` uses) — one prompt per repo, so still a serialized review, and nothing can be generated in parallel behind it.
- **One AI call over every repo's diff** — cheaper, but produces a single message that would have to be split by hand (or mis-applied) across independent repos and, critically, cannot describe the parent's bump commit.
- **Message per repo on one line in the picker** — dropped; bodies need to be read side by side, which is what the `$EDITOR` buffer is for.
- **Empty new commit message per file, one file per repo, in a multi-buffer editor** (nano/vim `-O`, etc.) — rejected as the primary mechanism: it depends on editor-specific multi-file flags, and deletion semantics ("drop this block") are clearer in one plain text buffer.
- **Interrupting the flow to auto-commit lazily** — rejected: committing before the submodule push succeeded would leave the parent pinning SHAs that no remote has.

## Related
ADR 0004 covers `aic` itself, including the `--generate` contract `aicp` reuses.