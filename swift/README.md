# Swift apps

Three small native macOS apps that back the ricing setup. Each is a standalone
SwiftPM package with **no third-party dependencies** - only Apple frameworks. You
build them from source; nothing here ships as a prebuilt binary.

| App | What it does | Trigger | Permissions needed |
|-----|--------------|---------|--------------------|
| **WorkspacePeek** | Overlay to see/switch tiling workspaces | Option + W | Accessibility + Screen Recording |
| **WallpaperPeek** | Grid picker for `~/Downloads/wallpapers` | Option + Q | Accessibility |
| **WalNotify** | The floating "wallpaper changed" HUD | called from `wal/postrun` | none |

## Prerequisites

- **macOS 14 (Sonoma) or newer** - the deployment target. Runs fine on 15 / 26.
- **Xcode Command Line Tools** - provides the Swift compiler. Full Xcode is *not*
  required:
  ```sh
  xcode-select --install
  ```

That's the whole list. No Homebrew, no package manager, no libraries to fetch.

## Build

Each app has its own `install.sh`. From the repo root:

```sh
cd swift/WorkspacePeek && ./install.sh
cd swift/WallpaperPeek && ./install.sh
cd swift/WalNotify     && ./install.sh
```

Each script: `swift build -c release` → wraps the binary in a `.app` → signs it
(ad-hoc, hardened runtime) → installs to `/Applications` → launches it. If you
just want the raw binary, `swift build -c release` on its own is enough.

On first launch macOS will ask for the permissions in the table above
(**System Settings → Privacy & Security**). WorkspacePeek needs **Accessibility**
for its global hotkey and **Screen Recording** to snapshot each workspace;
WallpaperPeek needs only **Accessibility**. WalNotify needs nothing.

## Is this safe? (yes, and here's how to verify it yourself)

I wrote these for my own machine, and there's no malicious code. Rather than ask
you to trust that, here's what makes it checkable:

- **No network access, at all.** None of the apps open a connection, make an HTTP
  request, or phone home. Verify it:
  ```sh
  grep -rn "URLSession\|URLRequest\|URLConnection\|Socket\|http" swift/*/Sources
  ```
  returns nothing. Nothing leaves your machine.
- **No third-party code.** Every `Package.swift` has an empty dependency list -
  the build fetches nothing from the internet. Only Apple frameworks (AppKit,
  ScreenCaptureKit, Carbon) are linked.
- **No telemetry, no analytics, no background daemons** beyond the app itself.
- **It's small.** Each app is a few hundred lines of readable Swift - auditable
  in one sitting.
- **The permissions map 1:1 to visible features** - the hotkey (Accessibility)
  and the workspace thumbnails (Screen Recording). Nothing broader is requested.
- **You do the signing.** The scripts sign ad-hoc on *your* machine; this repo
  contains no signing certificate, key, or Apple identity.

## Signing & distribution

The scripts sign ad-hoc (`--sign -`) with **hardened runtime** on, which blocks
code injection and dylib hijacking. That's ideal for building on your own machine.

Because it's ad-hoc (not notarized), the first time you open the app Gatekeeper
may make you **right-click → Open** once. That's normal for software you build
yourself. Full Gatekeeper-clean distribution would need a **Developer ID
Application** certificate (paid Apple Developer Program) plus notarization:

```sh
xcrun notarytool submit App.zip --keychain-profile <profile> --wait
xcrun stapler staple App.app
```

## Entitlements

Kept as tight as each app needs - and none of the dangerous ones
(`disable-library-validation`, `allow-jit`, `get-task-allow`, …) are present.

```
WorkspacePeek:  app-sandbox = false   (needs Accessibility APIs; can't be sandboxed)
                screen-capture = true (workspace thumbnails)
WallpaperPeek:  app-sandbox = false   (needs Accessibility APIs)
WalNotify:      no entitlements
```
