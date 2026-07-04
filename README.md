# dotfiles

My macOS desktop setup for macOS Sequoia 15.7.7! This setup is highly inspired by breadonpenguin's setup on Linux, just recreated on macOS. It uses pywal to recolour the system based on the current wallpaper. 

It's primarily made for Sequoia, but I've also tested it on macOS 26 (Tahoe). The Swift apps (WorkspacePeek, WallpaperPeek, WalNotify) build and run fine there, and sketchybar + rift work too. pywal was the one thing that didn't set up cleanly on a fresh Tahoe box (more on that below), everything else just falls back to the built in palettes without it. 

In the past, I used Aerospace for window management (like i3 tiling), though I now prefer to use [rift](https://github.com/acsandmann/rift) (a scrolling tiler on macOS). The menu bar is sketchybar, and I have some custom native swift apps (WallpaperPeek, WorkspacePeek, WalNotify, etc.) that I use to navigate stuff.

## Usage

Two scripts, depending on how much you want:

> **`./bootstrap.sh`** --> full fresh-machine setup. Installs the brew deps (rift, sketchybar, borders, etc.), builds the Swift apps, then runs `install.sh` for you. This is the one for a clean Mac.
>
> **`./install.sh`** --> just symlinks the configs into `~/.config` (and wires up the pywal backend). Run this on its own if you already have the tools and only want my configs.

I had trouble getting pywal to work on a fresh install macOS 26, so `bootstrap.sh` skips installing it. Everything still runs without it, the Swift apps just fall back to a built-in palette. See [Customising the colours](#customising-the-colours) if you want the live wallpaper-driven theming.

## Layout

```
config/            
  wal/             pywal stuff, scripts and postrun
  rift/            window manager config + bunch of global keybinds
  zen/             Zen browser theming mods (installed w Sine on Version 1.20.2b)
  sketchybar/      top menu bar
  borders/         JankyBorders (bordersrc is generated)
  aerospace/       tiling WM (old one i used before, rift is my current wm)
  btop/  yazi/  spotify-player/  nvim/  cava/  wezterm/  starship.toml
  wallpaperpeek/ walnotify/ workspacepeek/   tuning configs for the Swift apps
bin/               ~/.local/bin scripts (wallpaper picker, ws-capture, aerospace-switcher)
swift/             native helper apps - see swift/README.md (build each via install.sh)
  WorkspacePeek/       workspace switcher (Option+W)
  WallpaperPeek/       wallpaper picker   (Option+Q)
  WalNotify/           wallpaper-change toast
pywal-backend/     balanced.py - custom pywal backend (symlinked into site-packages)
launchagents/      com.user.wal-watch.plist - wallpaper-change watcher
```

## Wallpapers

WallpaperPeek looks at `~/Downloads/wallpapers`, so drop your own images in there (or point it somewhere else). 

*NOTE: I don't own the artwork so I'm not shipping my wallpaper collection in here. Some of them are also edits or collages I made from the originals, so for those you won't find the exact wallpaper anywhere, just the source art I pulled from. What I use is credited in [CREDITS.md](CREDITS.md) :). If you're the original creator and want it credited differently or taken down, open an issue.

## Zen browser theming (lowk kinda jank lol)

`config/zen/` holds two [Sine](https://github.com/CosmoCreeper/Sine) mods (`matugen-bridge`,  `matugen-wabi`). Also contrary to it being called matugen, the theming pipeline is actually still driven mostly by pywal; I was just trying to shoehorn parazeeknova's [zen-wabi](https://github.com/parazeeknova/zen-wabi) into my setup but it didn't really work out lol

You can install them through Sine into your Zen profile's `chrome/sine-mods/`. `Alt+T` should toggle the theming off and on using a rift global hotkey (`config/rift/webtheme-toggle.sh`). 

## How the wallpaper --> theme pipeline works

1. **`wal-wallpaper-watch.sh`** (LaunchAgent) watches the macOS wallpaper store for any changes. After changing a wallpaper through WallpaperPeek, it'll run `wal -i <img> --backend balanced` to grab a colour palette, then `postrun`.
2. **`balanced`** is a custom pywal backend (`pywal-backend/balanced.py`) that tries to spread colours across the brightness range of the image. So basically: dark zones will fill in background colours, light zone fill in foreground colours (like text), mid colours fill in accents.
3. **`postrun`** distributes the palette out to all the relevant apps with separate live-reload mechanisms for each (OSC for WezTerm panes, `--reload` for sketchybar, `SIGUSR2` for btop, regenerates `bordersrc`, etc.

## Customising the colours

Everything in here (sketchybar, borders, btop, wezterm, the Swift apps...) reads its colours from the one file: `~/.cache/wal/colors.json`, which pywal regenerates each time the wallpaper changes. So there's basically two ways to reskin the whole thing:

- **Change the wallpaper.** Pick a new one in WallpaperPeek and the `balanced` backend pulls a fresh palette out of it and pushes it everywhere else
- **Tweak how the palette gets built.** `pywal-backend/balanced.py` has the knobs. Or just swap `--backend balanced` in `config/wal/wal-wallpaper-watch.sh` for any stock pywal backend if you don't like mine.

Heads up if you're setting this up yourself: the pipeline is pinned to my own python (`~/miniconda3`) in `config/wal/postrun` and `wal-wallpaper-watch.sh`, and the `balanced` backend needs Pillow + numpy. So point those two paths at your own python and `pip install pywal Pillow numpy`.

The Swift apps (WallpaperPeek / WorkspacePeek / WalNotify) read `colors.json` live too, and if it's not there they fall back to a hardcoded palette (that's the pink you'll see before pywal is going). To change that fallback without bothering with pywal at all, edit the hex values in each app's `WalColors.swift` and rebuild.

## Custom rift keybinds

rift has no default keybinds so the whole keymap is in `config/rift/config.toml` (it's commented if you wanna read through it). Most of it is just native rift stuff (focus/move/resize w Alt + hjkl, Alt + 1-9 for workspaces, etc). But a few keys run little scripts I wrote for stuff rift can't do on its own:

- **Alt + M** --> maximise / "monocle" the focused column
- **Alt + Shift + [ / ]** --> resize a window's height inside a stacked column (jank atm)
- **Alt + T** --> toggle the pywal web-page recolouring in Zen
- **Alt + Shift + N** --> toggle Neru (keyboard-nav daemon) on/off
- **Alt + Shift + U** --> bulk-unload background Zen tabs to free up RAM
- **Alt + Shift + B** --> relaunch JankyBorders 

For the native rift keys check the [rift wiki](https://github.com/acsandmann/rift/wiki/Config).

## Light / dark switch (work in progress)

I will finish this eventually.. probably lol

`~/.config/wal/wal-mode.sh light | dark | toggle`
