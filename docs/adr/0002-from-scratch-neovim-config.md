# ADR 0002: From-scratch Neovim config over a starter distribution

## Status
Accepted

## Context
Neovim has a rich ecosystem of "starter distributions" (NVChad, LazyVim, AstroNvim, LunarVim) that bundle opinionated defaults, pre-configured plugins, and a UI layer on top of bare Neovim. The alternative is building a config from scratch using lazy.nvim directly.

## Decision
Build the Neovim config from scratch. Use lazy.nvim as the plugin manager, with a multi-file layout (`lua/config/` for options/keymaps/bootstrap, `lua/plugins/` for plugin specs). Initial plugin set: which-key.nvim, neo-tree.nvim, gitsigns.nvim, snacks.nvim (covers lazygit, notifications, terminal, indent guides).

## Alternatives considered
- **NVChad** — fast and opinionated, ships with a theme system and statusline. Hard to override defaults without fighting the framework; updates can break custom config.
- **LazyVim** — built on lazy.nvim, well-maintained by folke. Lower friction than NVChad but still a framework you configure around rather than build from.
- **AstroNvim** — community-driven, very batteries-included. Same problem: customisation means learning the framework's extension points, not just Neovim's.

## Consequences
- Full understanding of every plugin and keymap — nothing is hidden in a framework layer.
- Adding new functionality requires finding and configuring the plugin explicitly; no defaults are provided.
- Upgrading plugins is handled by lazy.nvim's `:Lazy update`; no framework version to track or migrate.
- Config is portable to any machine without a starter-distribution dependency.
