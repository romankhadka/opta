# Opta

Opta is a native macOS window switcher for people who want Option-based cycling:

- `Option` + `Tab` cycles through visible windows from all applications.
- `Option` + `` ` `` cycles through visible windows from the current application.
- Add `Shift` to either shortcut to cycle backward.
- Release `Option` to activate the selected window.
- Hover a tile to select it.
- Click a tile to activate that window immediately.
- Use the menu bar item to turn Launch at Login on or off.

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

## Permissions

On first launch, Opta asks macOS for Accessibility, Input Monitoring, and Screen Recording access. If the prompts do not appear, use the menu bar icon:

- Open Accessibility Settings
- Open Input Monitoring Settings
- Open Screen Recording Settings

After enabling any permission, relaunch Opta so macOS applies the change.

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

Windows are ordered by the system window list's front-to-back order, which
tracks recent use for visible windows. The first key press starts on the second
window in that list, so the frontmost window is skipped unless you cycle back to
it. Minimized and hidden windows are excluded. Windows from Opta itself are
excluded.

## License

MIT
