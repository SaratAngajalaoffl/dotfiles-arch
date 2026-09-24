# Quickshell migration plan

Status: **plan only** — nothing implemented yet.
Written: 2026-09-24

## Goal

Replace `waybar` + `rofi` + `dunst` + `eww` + `hyprpaper` with a single
Quickshell shell, styled after the bleeding-edge + notch look from
[Brainitech/Brain_Shell](https://github.com/Brainitech/Brain_Shell).

## Environment facts (verified)

| Thing | State |
| --- | --- |
| Hyprland | `0.56.2-3`, running on Wayland, config is **Lua** (`hl.*` API) |
| Monitors | `DP-3` @ `0x0`, `HDMI-A-2` @ `2560x0` — both scale 1 |
| `quickshell` | **`extra/quickshell` 0.3.1** (upstream tag `v0.3.1`, 2026-08-21) — no AUR build needed |
| `matugen` | `extra/matugen` 4.2.0 |
| `awww` | `extra/awww` 0.12.1 — this is the maintained `swww` fork, animated wallpaper support |
| Brain_Shell target | `hyprland v0.55+` + `quickshell` — matches, so no version gamble |

## Design decisions I need you to confirm

These change the shape of the whole thing, so I want answers before Chunk 1.

1. **Palette source: matugen, or keep the `theme` submodule?**
   Brain_Shell drives all colours from the wallpaper via matugen → `colors.json`.
   You already have 20 hand-built themes in `dotfiles-theme` + `theme-set.sh` +
   `theme-menu.sh` (SUPER+CTRL+SPACE). Replacing that with matugen throws away
   that submodule. My recommendation: **keep `dotfiles-theme` as the source of
   truth**, add a small `quickshell-colors.json` to each theme directory (same
   26-key palette, generated once from the existing `waybar-colors.css`), and
   have the shell watch `~/.config/theme/current/`. Matugen becomes optional
   later if you want wallpaper-derived colours. **I will assume this unless you
   say otherwise.**
2. **`rofi` — full replacement or keep for the long tail?**
   The bar's launcher (SUPER+SPACE) moves to a Quickshell popup easily. But
   `rofi-emoji`, `rofi -show window`, and any script in `dotfiles-bin` that
   shells out to rofi will break. Recommendation: replace `-show combi` and
   `-show drun` with a QML launcher; keep `rofi-emoji` for now.
3. **Is this machine the only one?** `dotfiles-hypr`, `dotfiles-kitty` etc. are
   shared app repos (the macOS parent also consumes some). A `dotfiles-quickshell`
   repo is Arch/Hyprland-only, which is fine, but the `hypr` repo edits in
   Chunk 1 would land on every machine that uses `dotfiles-hypr`. Confirm that's
   acceptable (it is, since `quickshell` only autostarts on Arch).
4. **`hypr` submodule has uncommitted local edits** right now
   (`conf/hyprland/look_and_feel.lua`, `conf/variables.conf`). Those need to be
   committed or stashed before Chunk 1 touches that repo.

## Decisions I'm making without asking (cheap to change)

- **Two "editions" of the shell, not one.** Brain_Shell's `SeamlessBarShape` is
  a three-notch Canvas shape. That's the look you liked, so `TopBar` is
  brain-shaped. But "I like the bleeding edge + frame" and "persist
  notifications" are independent of that, so the frame (`Border.qml`) and the
  services (`NotificationService`, `SettingsService`, …) are written to be
  reusable regardless of bar shape.
- **Colour keys are Catppuccin's 26 names.** Your `waybar-colors.css` already
  carries them, and Brain_Shell's `NotificationList.qml` + `nvim` colorscheme
  already speak that vocabulary. No new palette format invented.
- **No new `packages` section type.** `quickshell`, `matugen`, `awww` all go
  under the existing `pacman:` section. `eww-git` comes out of `aur:`.
- **Runtime state lives in `~/.local/state/quickshell/`**, not `~/.cache` and
  not the repo: `notifications.json`, `settings.json`, `pomodoro.json`,
  `wallpaper.json`. Gitignored, machine-local, survives restarts.
- **Reuse, don't rewrite:** `cliphist`, `wireplumber`/`wpctl`, `playerctl`,
  `nmcli`, `bluetoothctl`, `brightnessctl` — all already installed, all already
  driven by scripts in `dotfiles-eww`. The shell calls the same CLIs from QML
  `Process`/`Quickshell.Services.*` instead of from bash+`jq`.

## Target architecture

```
dotfiles-arch/
├── quickshell/                    ← NEW submodule (dotfiles-quickshell)
│   ├── .links                     config:~/.config/quickshell
│   ├── config/
│   │   ├── shell.qml              entrypoint
│   │   ├── theme/                 Colors.qml, Metrics.qml, Theme.qml (singletons)
│   │   ├── services/              NotificationService, SettingsService, PomodoroService,
│   │   │                          WallpaperService, AudioService, NetworkService,
│   │   │                          BluetoothService, ClipboardService, MediaService,
│   │   │                          SystemStatsService, BrightnessService
│   │   ├── components/            PopupSlide, Notch, Toggle, Slider, IconButton, Card
│   │   ├── shapes/                SeamlessBarShape, FrameShape (Canvas)
│   │   ├── windows/               TopBar, Frame, PopupDismiss
│   │   ├── modules/               Left/ Center/ Right/ (bar notch content)
│   │   └── popups/                PopupLayer + one file per popup
│   └── scripts/                   only the CLI shims that aren't worth QML-ing
├── hypr/                          autostart + layerrules + keybinds point at quickshell
├── theme/                         + quickshell-colors.json per theme (Chunk 2)
├── kitty/                         + settings knobs read from settings.json (Chunk 5)
└── waybar/ rofi/ dunst/ eww/      deleted (Chunk 6)
```

## Inventory — what has to be reimplemented

Everything below is currently a live feature. Nothing gets deleted until its
replacement is verified, so this is the real checklist.

### From `waybar` (`config.jsonc` + `modules.json`)

| Module | Replacement | Notes |
| --- | --- | --- |
| `hyprland/workspaces` | `modules/Left/Workspaces.qml` | pills, `persistent_workspaces: 5`, per-monitor (current config is `all-outputs: true`) |
| `clock` | `modules/Center/Clock.qml` | was `%a, %d %b, %I:%M:%S %p`, click → calendar |
| `custom/playback` | `services/MediaService.qml` | `playerctl`; Brain_Shell uses MPRIS directly — use `Quickshell.Services.Mpris` |
| `custom/spotify` | `popups/SpotifyPopup.qml` | uses the `spotify-search` keyring secrets |
| `wireplumber` | `services/AudioService.qml` | click → audio popup |
| `custom/bluetooth` | `services/BluetoothService.qml` | |
| `custom/clipboard` | `popups/ClipboardPopup.qml` | `cliphist` |
| `tray` | `modules/Right/SysTray.qml` | `Quickshell.Services.SystemTray` |
| `custom/user` | `popups/UserMenu.qml` | lock / reboot / shutdown + update count |
| — | `modules/Right/Network.qml` | new (waybar had none; eww did) |
| — | `modules/Right/Notifications.qml` | new — bell + unread badge |

### From `eww` (5 windows)

| eww window | Replacement |
| --- | --- |
| `user-menu` | `popups/UserMenu.qml` |
| `audio-control` | `popups/AudioPopup.qml` (sinks + sources + per-app streams) |
| `bluetooth-control` | `popups/BluetoothPopup.qml` |
| `clipboard-history` | `popups/ClipboardPopup.qml` |
| `spotify-control` | `popups/SpotifyPopup.qml` (search, playlists, transport) |
| `eww-open.sh` monitor-under-cursor logic | gone — Quickshell has `Quickshell.screens`, popups are per-screen `Variants` |

### From `dunst` + `rofi` + `hyprpaper`

| Thing | Replacement |
| --- | --- |
| `dunstrc` | `services/NotificationService.qml` (`NotificationServer`) — **and it becomes persistent**, see below |
| `rofi -show combi` (SUPER+SPACE) | `popups/AppLauncher.qml` |
| `rofi` theme picker (SUPER+CTRL+SPACE) | `popups/Dashboard.qml` → Customise tab → Themes |
| `hyprpaper` | `services/WallpaperService.qml` over `awww` |
| `~/.local/bin/toggle_rofi.sh`, `reload_dunst.sh`, `reload_waybar.sh`, `reload_eww.sh` | deleted in Chunk 6 |

### From `theme/bin`

| Script | Fate |
| --- | --- |
| `theme-set.sh` | keep, but the reload block changes: `reload_all_services.sh` → `qs ipc call theme reload` |
| `theme-menu.sh` | keep for CLI use; the GUI path becomes the Dashboard Customise tab |
| `select_wallpaper.sh` | keep — still writes `~/.cache/appearance/wallpaper.png`; `WallpaperService` calls it and then `awww` |

---

# Chunks

## Chunk 0 — Spike (throwaway, no repo changes)

**Goal:** prove Quickshell 0.3.1 renders the notch shape on *your* hardware and
that `awww` animates, before any repo surgery. Timeboxed to one session.

1. Install `quickshell`, `matugen`, `awww` yourself (I can't install packages):
   ```bash
   sudo pacman -S --needed quickshell matugen awww
   ```
2. Scratch config at `/tmp/qs-spike/shell.qml` (no `~/.config` writes) —
   one `PanelWindow` per screen with a Canvas notch in the middle and a clock.
   Run with `qs -c /tmp/qs-spike` and screenshot.
3. Check: does `Quickshell.screens` see both `DP-3` and `HDMI-A-2`? Does the
   `layerrule` blur apply to a quickshell layer surface (needs `hyprctl
   layers`)?
4. Try `awww img <gif> --transition-type grow` and confirm animation plays.

**Exit criteria:** notch renders correctly on both monitors, blur applies,
awww animates a gif. If any fail, we find out before writing 40 QML files.

### Chunk 0 result: **GO** (2026-09-24)

Spike lives at `/tmp/qs-spike` (throwaway). All four criteria passed, and the
spike surfaced four findings that change the plan below.

| # | Check | Result |
| --- | --- | --- |
| 1 | Seamless three-notch bar on both monitors | **PASS** — correct on `DP-3` and `HDMI-A-2` |
| 2 | Frame around screen (even-odd cut) | **PASS** — `ctx.fill("evenodd")` punches the hole correctly |
| 3 | Blur on a quickshell layer surface | **PASS** — but see F3/F6, it is not uniform |
| 4 | awww animated wallpaper | **PASS** — gif animates, per-output |

#### F1 — Do not redeclare `screen` on a `PanelWindow`

`Bar.qml` declared `required property var screen`, which **shadows
`PanelWindow`'s built-in `screen`**. Symptoms: two bar windows stacked on
`DP-3` (each pushing the next down via `exclusiveZone`) and **no bar at all on
`HDMI-A-2`**. `Frame.qml`, which did not redeclare it, was correct on both.

Rule: inside a window, only *read* `screen`; never declare it. If you need it
under another name, use `readonly property var screenRef: screen`.
Brain_Shell's `TopBar.qml` follows this — it only reads it.

#### F2 — `hyprctl keyword` is dead on this setup; use `hyprctl eval`

Hyprland 0.56.2 with a Lua config uses the **non-legacy parser**:

```
$ hyprctl keyword layerrule 'blur,quickshell'
keyword can't work with non-legacy parsers. Use eval.
```

This invalidates the Chunk 5d mechanism as written. The Customise tab must emit
Lua, not keywords:

```bash
hyprctl eval 'hl.layer_rule({ match = { namespace = "quickshell" }, blur = true, ignore_alpha = 0.0 })'
```

Every "`hyprctl keyword`" row in the Chunk 5d table becomes a `hyprctl eval`
call with the `hl.*` equivalent. Note `hl.config({...})` works through `eval`
too, which is how `decoration:*_opacity` etc. get set at runtime.

#### F3 — Blur reaches `PanelWindow` layer surfaces, but **not `PopupWindow` subsurfaces**

Two separate tests, both A/B'd with the rule toggled:

- **`PanelWindow`, translucent, over a browser window** → blur applies cleanly.
  Faces and poster art behind it smear to colour blobs.
- **`PopupWindow` (child of the bar), translucent** → **no blur, regardless of
  the layerrule.** It is not a layer surface at all: it never appears in
  `hyprctl layers`, and it never appears in `hyprctl clients` either. It is a
  **subsurface of the parent layer surface**, so the rule is evaluated against
the parent (alpha 1, opaque) and `ignorealpha` can never match it.

This is why the first blur attempt looked like a no-op: I was testing the
wrong window type.

**Consequence — popups split by size:**

| Popup | Type | Blurred? |
| --- | --- | --- |
| Dashboard, Wallpaper, Clipboard, Network | `PanelWindow` | yes |
| AppLauncher, Notifications, Audio, Bluetooth, Spotify, UserMenu, Toast | `PopupWindow` | no — use opaque/near-opaque fill |

Brain_Shell's own source splits exactly this way (`Dashboard`,
`WallpaperPopup`, `ClipboardPopup`, `NetworkPopup` are `PanelWindow`;
`NotificationsPopup`, `AudioPopup`, `QuickControl`, `ArchMenu` are
`PopupWindow`) — it does **not** set any `layerrule` anywhere in the repo. So
its small popups are unblurred too; it is not a regression we are introducing.

If you want a blurred *small* popup later, it has to be a `PanelWindow` with a
positioned mask — more code, and it loses `anchor.window` convenience. Decide
per-popup, don't do it globally.

#### F4 — `qs -c quickshell` does NOT work; the invocation is plain `qs`

Quickshell detects configs as **subdirectories** of an XDG config dir:
`<xdg>/quickshell/<name>/shell.qml`. But if `<xdg>/quickshell/shell.qml`
exists, that is registered as the **`default`** config and *no subdirectories
are considered*.

Our `.links` maps the app repo's `config` directly onto `~/.config/quickshell`,
so `shell.qml` sits at `~/.config/quickshell/shell.qml` — the default config.
Verified:

```
$ qs -c quickshell
Could not find "quickshell" config directory in any valid config path.
$ qs                # works
$ qs -p ~/.config/quickshell   # also works
```

**Consequence:** `hl.exec_cmd("qs")` in `autostart.lua`, and any future IPC or
reload command, must not use `-c quickshell`. The layer namespace is
unaffected — it is still `quickshell` (confirmed with the running shell).

#### F5 — Lua mode changes `hyprctl dispatch` too, not just `keyword`

`hyprctl dispatch <arg>` wraps the argument as `hl.dispatch(<arg>)`. So a raw
shell command string is parsed as Lua and fails:

```
$ hyprctl dispatch exec "touch /tmp/x"
error: ...'exec'...: attempt to perform arithmetic on a nil value
```

The working forms:

```bash
hyprctl eval 'hl.dispatch(hl.dsp.exec_cmd("touch /tmp/x"))'   # explicit, works
```

This only affects interactive/scripted dispatch. `autostart.lua` already calls
`hl.exec_cmd(...)`, which is correct and unaffected — verified by launching the
shell through `hl.dispatch(hl.dsp.exec_cmd("qs"))`.

#### F6 — `ignorealpha` needs `alpha=1` surfaces to be useful

`hyprctl layers` reports `alpha: 1` for quickshell layer surfaces even when the
QML content is translucent, because the surface's alpha is per-pixel. So
`ignorealpha` does not gate blur the way you would expect from the wiki. Use
`ignore_alpha = 0.0` and rely on the QML fill's own alpha for the look.

#### F7 — awww is a drop-in for hyprpaper, and per-output

`awww-daemon` + `awww img <file> --outputs <name> --transition-type grow`
animated a 20-frame gif on `HDMI-A-2` while `DP-3` was untouched. `awww query`
reports per-output state. Note: **starting `awww-daemon` blanks both outputs**
(it takes over the layer), so `WallpaperService` must apply a wallpaper
immediately on startup, and `hyprpaper` should be stopped in the same commit
that starts awww — running both is a silent fight for the layer.


---

## Chunk 1 — Scaffold `dotfiles-quickshell` + wire Hyprland

**Goal:** empty-but-correct shell on the bar, waybar/eww still running
alongside it. Reversible in one commit.

1. Create `dotfiles-quickshell` (per the "Adding a new app" steps in
   `CLAUDE.md`), with `.links` = `config:~/.config/quickshell`.
2. Ship only: `shell.qml`, `theme/{Colors,Metrics,Theme}.qml`,
   `shapes/SeamlessBarShape.qml`, `shapes/FrameShape.qml`,
   `windows/TopBar.qml`, `windows/Frame.qml`, `windows/PopupDismiss.qml`,
   `components/PopupSlide.qml`, and a stub `modules/{Left,Center,Right}/`.
   No services yet — the bar shows workspaces + clock + a static bell.
3. `Colors.qml` reads `~/.config/theme/current/quickshell-colors.json` (Chunk 2
   creates the file; until then fall back to the Catppuccin Mocha literals).
4. Add to `hypr`:
   - `packages`: `quickshell`, `matugen`, `awww` under `pacman:`
   - `conf/hyprland/autostart.lua`: `hl.exec_cmd(vars.quickshell)` (plain `qs`
     — **not** `qs -c quickshell`, see F4), and **keep** `waybar`/`eww` for now
   - `conf/hyprland/windowrules.lua`: `hl.layer_rule` for the quickshell
     namespace — `blur = true`, `ignore_alpha = 0.0`
   - `conf/variables.lua`: `M.quickshell = "qs"`
5. Commit the pending `hypr` edits first (see decision 4).

**Status: DONE.** See the Chunk 1 result below.

### Chunk 1 result

Shell scaffolded in the new `dotfiles-quickshell` submodule (32 files) and wired
into Hyprland. Verified:

- `qs` loads with no errors; one bar + one frame per monitor on both `DP-3` and
  `HDMI-A-2`.
- Workspace pills render correctly — active workspace as a wide pill, empty ones
  as dots.
- Right notch renders all seven triggers (audio, network, bluetooth, clipboard,
  emoji, notifications, user).
- Layer namespace is `quickshell`; `hl.layer_rule` applies cleanly.
- `hyprctl reload` → `hyprctl configerrors` is empty.
- The autostart path is valid: `hl.dispatch(hl.dsp.exec_cmd("qs"))` starts the
  shell.

The only runtime warning is the expected missing
`~/.config/theme/current/quickshell-colors.json` — Chunk 2 creates it. Until
then the palette falls back to Catppuccin Mocha literals.

**Deliberate scope limit:** the popup triggers toggle `ShellState` flags that
nothing renders yet. Popups land in Chunk 4, and the state/wiring is testable
before the UI exists. Keybinds still point at `rofi` because rofi still runs.

**Exit criteria:** `qs` runs, bar with notches + frame visible,
no errors in `qs log`, both monitors correct, waybar still up.

---

## Chunk 2 — Theming: matugen generation + curated overrides

**Goal:** matugen generates themes from the wallpaper; you can also use the
hand-built themes; any theme can be overridden and committed.

**Decision (yours):** matugen is the generator, `dotfiles-theme` is the
store of truth. Generated themes are ephemeral until explicitly saved.

### Evidence: a theme IS a 26-value palette plus wallpapers

Measured across all 23 themes in `dotfiles-theme`:

| File | Keys | Cross-theme content differences |
| --- | --- | --- |
| `waybar-colors.css` | 26 | — (canonical source) |
| `eww-colors.scss` | 26 | **0** |
| `nvim-colors.lua` | 26 | **0** |
| `rofi-colors.rasi` | 26 (+175 identical lines) | **0** content, 44 comment/header |
| `kitty-theme.conf` | 39 | **0** content, 88 comment/header |
| `hyprland-colors.lua` | 2 | 88 — the border accent, see below |
| `dunstrc` | 6 | 352 — palette + per-theme extras, see below |

So **5 of 7 files are pure functions of the palette.** The other two are palette
plus one small declared input each.

**Border accent is a per-theme choice of palette key**, not a free value.
Measured: Catppuccin flavours use `red`, most omarchy ports use `blue`, and
`kanagawa`/`lumon`/`retro-82` use `text`/`mauve`/`peach`. Only 3 themes
(`hackerman`, `last-horizon`, `white`) hand-pick a value outside the palette.
Represent it as `BORDER_ACCENT=<palette-key>` in `theme.conf`.

**`dunstrc` is palette-derived for 20 of 23 themes.** Only 3 have any
non-palette value, and `catppuccin-mocha` — the default — is the worst, with 9
stray values including a magenta `#cd0373` that appears in no palette.
**That file is stale: your default theme's dunst has never matched its own
colours.** A rebuild fixes it.

### Target structure

```
dotfiles-theme/config/
  themes/<name>/
    palette.json          <- SOURCE OF TRUTH: 26 keys
    theme.conf            <- THEME_NAME, THEME_MODE, QT_SCHEME, BORDER_ACCENT
    backgrounds/
    overrides/            <- optional, per theme
      palette.json        <-   partial patch, merged over the palette
      dunstrc             <-   or a whole file, applied verbatim
  templates/              <- shared by all themes, one per output file
    waybar-colors.css.tpl  rofi-colors.rasi.tpl   kitty-theme.conf.tpl
    hyprland-colors.lua.tpl  nvim-colors.lua.tpl  dunstrc.tpl  quickshell-colors.json.tpl
  matugen.toml            <- template wiring for matugen
```

### Resolution order

1. **palette** — from `palette.json` (curated) or matugen-from-wallpaper (generated)
2. **patch** — merge `overrides/palette.json` on top
3. **render** — `templates/*.tpl` → per-app files
4. **verbatim** — `overrides/<filename>` wins outright if present (escape hatch)

Step 4 is what makes hand-tuned files like `dunstrc` a non-issue: drop the
whole file in `overrides/` and it is used as-is.

### Generated vs curated

- `matugen image <wallpaper>` writes to
  `~/.local/state/theme/generated/<slug>/` — ephemeral, **never in the repo**.
- **Save/promote** copies that into `dotfiles-theme/config/themes/<slug>/`,
  where it becomes a normal curated theme: hand-editable, committable, and
  visible to `theme-menu.sh` alongside the other 23.
- `theme-set.sh` accepts either, so nothing changes about how you switch.

### Steps

1. Build `theme-gen.py` (lives in `dotfiles-theme/bin/`) implementing the
   resolution order above. Add `quickshell-colors.json` as an 8th template so
   the shell gets its palette the same way every other app does.
2. **Verify byte-for-byte** against the current 23 themes before committing.
   Prototype at `/tmp/theme-gen/gen.py` already reproduces 73/161 file-theme
   pairs exactly, with all remaining diffs accounted for (headers + the two
   declared inputs above). Expect ~100% after adding `BORDER_ACCENT`,
   header templating, and `dunstrc` overrides.
3. Collapse each theme dir: keep `palette.json` + `theme.conf` + `backgrounds/`,
   delete the 7 rendered files, add `overrides/` only where needed
   (3 themes for dunst, 3 for the border accent).
4. `matugen.toml` + a `theme-generate.sh` entry point.
5. `Colors.qml` watches `~/.config/theme/current/quickshell-colors.json` via
   `FileView { watchChanges: true }` — Brain_Shell's `ColorLoader.qml` pattern.
6. `theme-set.sh`: point at the new file, replace `reload_all_services.sh`
   with `qs ipc call theme reload`.
7. Dashboard Customise tab gets a **Themes** section: pick from the 23 curated
   themes, generate from the current wallpaper, or save the generated one.

**Exit criteria:**
- `theme-gen.py` reproduces the committed tree byte-for-byte (verified, not assumed)
- `theme-set.sh gruvbox` recolours the shell live, no restart
- generate-from-wallpaper produces a theme; save promotes it into the repo
- an `overrides/` edit wins over the generated value

**Risk / rollback:** steps 1–2 are additive and touch nothing. Step 3 is the
destructive one (deletes 7 files × 23 themes) and must only run **after** the
byte-for-byte check passes, in its own commit, so `git revert` restores the
rendered files.

---

## Chunk 3 — Bar content parity

**Goal:** the bar does everything waybar did.

1. `modules/Left/Workspaces.qml` — pills, active/occupied/empty/urgent, click
   to activate, scroll to cycle, per-monitor filtering, persistent 5.
2. `modules/Center/Clock.qml` — time + date, click → Dashboard (calendar tab).
3. `modules/Right/` — `SysTray`, `Network`, `Bluetooth`, `Audio`, `Battery`,
   `Notifications` (badge = unread count), `Media`.
4. Services for each, backed by `Quickshell.Services.*` where it exists
   (`Pipewire`, `UPower`, `Mpris`, `SystemTray`, `Notifications`) and `Process`
   + the existing CLI for the rest (`nmcli`, `bluetoothctl`, `brightnessctl`).
5. Media: `Quickshell.Services.Mpris` instead of the
   `current_playback.sh`/`should_show_playback.sh` scripts — delete those.

**Exit criteria:** visually + functionally ≥ waybar. Side-by-side screenshot.

---

## Chunk 4 — Popups + notifications (your goal #2)

**Goal:** every popup slides, and notifications never disappear on their own.

1. `components/PopupSlide.qml` — the slide+fade container (Brain_Shell's
   pattern: `Behavior on x/y` + `NumberAnimation { OutCubic }`, plus a
   `closeDelay` so moving from trigger → popup doesn't flicker).

   **Window type per popup, per finding F3:** big popups (`Dashboard`,
   `WallpaperPopup`, `ClipboardPopup`, `NetworkPopup`) are `PanelWindow` and can
   be blurred; small anchored popups are `PopupWindow` and must use a
   near-opaque fill, because Hyprland will not blur a subsurface. Decide the
   window type when creating each popup, not afterwards.
2. `popups/PopupLayer.qml` + one file per popup, in this order:
   `AudioPopup`, `BluetoothPopup`, `NetworkPopup`, `ClipboardPopup`,
   `UserMenu`, `AppLauncher`, `NotificationToast`, `NotificationsPopup`,
   `Dashboard`, `SpotifyPopup`.
3. **Persistent notifications.** This is the part with no upstream equivalent:
   - `NotificationServer { keepOnReload: true }`
   - Force `notification.expireTimeout = 0` (freedesktop: never expire) so
     nothing auto-dismisses.
   - On `onNotification`: push to `active[]`, emit a toast, snapshot to
     `~/.local/state/quickshell/notifications.json`.
   - Panel has **three actions per item**: `✕` delete, `✓` mark-as-read
     (moves `active` → `history`, clears the badge), and action buttons
     (`n.actions[].invoke()`) — Brain_Shell already renders these, keep it.
   - `history[]` survives restart (rehydrated from JSON as read-only cards —
     note: `invoke()` can't work on a restored notification, so restored cards
     show text only, no action buttons).
   - Panel header: unread count, "Mark all read", "Clear all".
   - DND toggle in QuickControls suppresses toasts but still records to
     `active` (current behaviour via `ShellState.dnd` keeps this).
4. `windows/PopupDismiss.qml` — click-outside + Escape closes everything.

**Exit criteria:** `notify-send a b` → toast slides in, stays; bell badge
increments; restart the shell → notification still in the panel; mark-as-read
clears the badge but keeps the card in history.

---

## Chunk 5 — Custom widgets (your goals #3 and #4)

Five tabs in the Dashboard. Independent — could be five separate commits.

**5a. Wallpaper manager** (`popups/WallpaperPopup.qml` +
`services/WallpaperService.qml`)
- Grid of `~/Pictures/Wallpapers` (dir doesn't exist yet — create it, or point
  at the active theme's `backgrounds/`).
- Thumbnail grid; click → `awww img` with a transition selector
  (`grow` / `fade` / `wipe` / `outer`, duration slider).
- Animated: `.gif`/`.mp4` handled by awww directly. **This is your goal #3** —
  awww replaces hyprpaper, and the *transition* is the animation. If you meant
  video wallpapers specifically, that's `mpvpaper` and a different design —
  say so and I'll adjust.
- Per-monitor apply (two monitors) + "apply to all".
- Writes `~/.local/state/quickshell/wallpaper.json`; `select_wallpaper.sh`
  keeps owning the theme day/night wallpaper → `~/.cache/appearance/wallpaper.png`.

**5b. Calendar** (`popups/Dashboard.qml` → Home tab)
- Month grid, today highlighted, week numbers, click a day → jumps month.
- Below it: next-up events. If you want real events, that needs `khal`/CalDAV
  or Google Calendar — out of scope unless you ask.

**5c. Pomodoro** (`services/PomodoroService.qml` + Home tab card)
- work/short/long durations, long-break interval, auto-start next session.
- Ring progress in the center notch while running.
- On completion: a notification through our own `NotificationService` (so it
  lands in the persistent panel) + optional sound.
- State in `~/.local/state/quickshell/pomodoro.json` so a shell restart
  doesn't lose the session.

**5d. Customise tab** — the settings surface. Each row writes to
`~/.local/state/quickshell/settings.json` and applies live:

| Setting | Mechanism |
| --- | --- |
| `blur:enabled`, `blur:size`, `blur:passes` | `hyprctl keyword decoration:blur:*` |
| `active_opacity`, `inactive_opacity` | `hyprctl keyword decoration:*_opacity` |
| `animations:enabled` | `hyprctl keyword animations:enabled` |
| `gaps_in`, `gaps_out`, `rounding`, `shadow:enabled` | `hyprctl keyword` |
| `cursor_trail`, `cursor_trail_decay`, `cursor_trail_start_threshold` | rewrite `~/.config/kitty/user-settings.conf` + `kill -SIGUSR1` kitty |
| `background_opacity`, `font_size` | same kitty path |
| bar height / notch sizes / animation duration | live QML property (`Metrics`) |
| focus mode (bar → edge strip) | `ShellState.focusMode` |
| DND | `NotificationService` |

**Note on `cursor_trail`:** kitty's `cursor_trail` exists, and kitty already
gitignores `current-theme.conf` (theme-owned). A new `user-settings.conf`,
also gitignored, is where these runtime knobs go — `kitty.conf` gets one
`include user-settings.conf` line. Clean, and doesn't fight the theme symlink.

**5e. Spotify popup** — port `eww`'s search/playlists/transport as-is, same
`spotify-search` keyring secrets (`.secrets` entry moves from `eww` to
`quickshell`).

**5f. Emoji picker** — replaces `rofi-emoji`, lives in the top-right dropdown
(next to the notification bell). Needs a bundled emoji dataset: ship
`emoji.json` in the repo (name → glyph, ~1800 entries) and filter it in QML,
rather than shelling out. Selecting an emoji copies it via `wl-copy` and,
optionally, types it with `wtype` — **`wtype` is not installed** (checked in
Chunk 0), so either add it to `packages` or make paste-only the default.

---

## Chunk 6 — Cutover

Only after every chunk above is verified.

1. Remove from `hypr/conf/hyprland/autostart.lua`: `waybar`, `eww daemon`,
   `hyprpaper`, `hyprsunset` (hyprsunset stays if you still use it — it's
   unrelated).
2. Repoint keybinds: `toggleRofiScript` → `qs ipc call launcher toggle`,
   `themeMenuScript` → `qs ipc call theme menu`.
3. `packages`: drop `waybar`, `dunst`, `rofi`, `hyprpaper`; drop `eww-git` from
   `aur:`.
4. Delete submodules: `waybar`, `dunst`, `rofi`, `eww` (and their GitHub repos
   — ask before deleting repos).
5. Delete scripts: `toggle_rofi.sh`, `reload_dunst.sh`, `reload_waybar.sh`,
   `reload_eww.sh`; rewrite `reload_all_services.sh` → `qs ipc call reload all`.
6. Update `CLAUDE.md` + `CONTEXT.md` (submodule table, theming section,
   "adding a new app" example).

**Rollback:** until step 4 the old configs are untouched on disk and
re-enabling them is one line in `autostart.lua`.

---

## Stale docs I noticed

`CLAUDE.md` and `CONTEXT.md` still describe the "incremental migration" state —
parent at `~/dotfiles-arch`, legacy flat repo `arch-dotfiles-v2` at `~/dotfiles`.
Reality: `~/dotfiles` **is** the `dotfiles-arch` parent (verified via
`git remote -v`), and there is no `~/dotfiles-arch`. Worth a docs fix in
Chunk 6, or now if you want it out of the way.

## Open questions

1. ~~Palette: keep `dotfiles-theme`, or go matugen?~~ **Answered:** matugen
   generates; `dotfiles-theme` stores. See Chunk 2.
2. ~~Animated wallpaper: video (`mpvpaper`)?~~ **Answered: no video.** Pictures
   only, switched with an awww transition. `awww` alone, no `mpvpaper`.
3. ~~`rofi`: drop entirely, or keep `rofi-emoji`?~~ **Answered: drop `rofi`
   entirely.** The emoji picker moves into the top-right dropdown as a
   Quickshell popup. So `rofi`, `rofi-emoji`, `dotfiles-rofi`, `config.rasi`,
   `fonts.rasi`, `colors.rasi` and `toggle_rofi.sh` all go in Chunk 6.
4. Calendar: display-only, or real CalDAV/Google events?
5. ~~Are the pending `hypr` submodule edits meant to be committed?~~ **Done.**
6. **matugen needs `--prefer`** when a wallpaper has multiple source colours
   (`saturation` / `lightness` / `closest-to-fallback`). Pick one as the
   default, or the Customise tab should expose it.
7. **Should `dotfiles-theme` still ship the 7 rendered files for apps that are
   not yet Quickshell?** After Chunk 6 nothing consumes `rofi-colors.rasi` or
   `eww-colors.scss`, but `kitty`/`nvim`/`hypr` still do. Keeping the generator
   means those are still produced — just from templates instead of committed.
