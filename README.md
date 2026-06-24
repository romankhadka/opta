# Opta

Opta is a native macOS window switcher for people who want Option-based cycling:

- `Option` + `Tab` cycles through visible windows from all applications.
- `Option` + `` ` `` cycles through visible windows from the current application.
- Release `Option` to activate the selected window.

The switcher shows live window previews when Screen Recording permission is available, then falls back to the application icon. Each tile includes the window title, application name, and app icon.

## Requirements

- macOS 14 or newer
- Xcode 26 or newer, or the matching Command Line Tools
- Accessibility permission for global keyboard capture and window activation
- Screen Recording permission for window previews

## Build

```bash
swift test
./scripts/build_app.sh
open .build/release/Opta.app
```

The build script creates `.build/release/Opta.app` and ad-hoc signs it for local use.

## Permissions

On first launch, Opta asks macOS for Accessibility and Screen Recording access. If the prompts do not appear, use the menu bar icon:

- Open Accessibility Settings
- Open Screen Recording Settings

After enabling either permission, relaunch Opta so macOS applies the change.

## Notes

Opta is intentionally small and native. It uses:

- `CGWindowListCopyWindowInfo` to discover visible windows.
- `ScreenCaptureKit` to capture window preview images.
- Accessibility APIs to focus and raise the selected window.
- A session event tap to intercept `Option` + `Tab` and `Option` + `` ` ``.

Minimized and hidden windows are excluded. Windows from Opta itself are excluded.

## License

MIT
