# Opta

Landing page: `docs/index.html`, ready to serve from GitHub Pages with the
Pages source set to the `docs` folder on `main`. It carries an interactive
switcher demo built from the shipped Quiet Glass tokens, so the panel on the
page is the panel in the app.

Opta is a native macOS window switcher for people who want Option-based cycling:

- `Option` + `Tab` cycles through visible windows from all applications.
- `Option` + `` ` `` cycles through visible windows from the current application.
- Add `Shift` to either shortcut to cycle backward.
- Release `Option` to activate the selected window.
- Press `Escape` to dismiss the switcher without activating anything.
- Hover a tile to select it.
- Click a tile to activate that window immediately.
- Use the menu bar item to toggle current-application cycling or Launch at Login.

The switcher shows live window previews when Screen Recording permission is available, then falls back to the application icon. Each tile includes the window title, application name, and app icon.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer, or the matching Command Line Tools
- Accessibility permission for window activation
- Input Monitoring permission for global keyboard capture
- Screen Recording permission for window previews

## Build

```bash
swift test
./scripts/build_app.sh
open .build/release/Opta.app
```

The build script creates `.build/release/Opta.app` and ad-hoc signs it for local use.

## Icon

The application icon is the Option key glyph on a blue steel field, kept in
`Resources/Opta.icon` as an Icon Composer document. `build_app.sh` compiles it
into the appearance-aware `Assets.car` that macOS 26 renders in Default, Dark,
Tinted, and Clear, plus an `.icns` for macOS 14 and 15.

```bash
./scripts/preview_icon.sh
```

That renders all six appearances to `.build/icon-preview`. It also fails if the
Dark rendition stops drawing the mark in white — the background colour and the
mark's colour are linked by a system rule that the design spec explains.

## Permissions

On first launch, Opta asks macOS for Accessibility, Input Monitoring, and Screen Recording access. If the prompts do not appear, use the menu bar icon:

- Open Accessibility Settings
- Open Input Monitoring Settings
- Open Screen Recording Settings

After enabling any permission, relaunch Opta so macOS applies the change.

## Current-application cycling

`Option` + `` ` `` is also the macOS grave-accent dead key used to type
characters such as à, è, ì, ò, and ù. If you type those, open the Opta menu bar
icon and turn off **Cycle Current App (⌥`)**; the dead key then passes through to
the focused app. `Option` + `Tab` cycling is unaffected. The choice is
remembered across launches.

## Launch at Login

Use the Opta menu bar icon and choose **Launch at Login**. macOS may require
approval in System Settings > General > Login Items; if the menu item shows a
mixed state, open Login Items Settings from the same menu and approve Opta.

## Notes

Opta is intentionally small and native. It uses:

- `CGWindowListCopyWindowInfo` to discover visible windows.
- `ScreenCaptureKit` to capture window preview images.
- `SMAppService.mainApp` to register the app as a launch-at-login item.
- Accessibility APIs to focus and raise the selected window.
- IOKit HID access to request Input Monitoring for keyboard capture.
- A session event tap to intercept `Option` + `Tab` and `Option` + `` ` ``.

Windows are ordered by most recent use. Opta records focus changes as they
happen — windows it activates itself, application switches (Dock, Cmd+Tab),
and focused-window changes inside each application — and falls back to the
system window list's front-to-back order for windows it has never seen
focused. The first key press starts on the second window in that order, so the
frontmost window is skipped unless you cycle back to it. Minimized and hidden
windows are excluded. Windows from Opta itself are excluded.

## License

MIT
