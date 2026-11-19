# Pilot Pro Own

An open-source, native macOS USB controller for the **XPPen Pilot Pro** (`28bd:0203`). Configure physical controls, switch between named pages, and assign keyboard shortcuts or multi-step macros.

[Documentació en català](README.ca.md) · [MIT license](LICENSE)

## Features

- Three wheels with paired clockwise/anticlockwise controls on the map: white outlined circles with opaque black interiors and direction arrows. Independent positive (+) and negative (−) actions. Choose which sign clockwise rotation executes, independently for each wheel and page.
- Eight side buttons (four on each side), four lower directional buttons, the joystick button and the small-wheel button.
- Eight exclusive joystick directions, including four independent diagonals that default to no action, with a **percentage dead zone**, 0.5 percentage-point slider increments, numeric entry and a live preview.
- Named pages such as **Timeline** and **Browser**, with independent shortcuts, macros, control names and response settings.
- Create, rename, duplicate and copy a complete page, including across profiles. Select individual controls with ⌘-click or the right-click menu, then right-click to copy their actions and labels to another page/profile.
- The left sidebar collects connection status, active profile and physical identification. The right inspector stays focused on the selected action. A separate floating Configuration window contains permissions, connection administration and configuration export.
- Built-in General and Final Cut Pro profiles; the foreground app selects the profile. Choose the page in the window or menu bar, or bind a controller button or sequence step to it.
- Click **Sense drecera** (No shortcut) or the current action to assign a keystroke or a page change. Every action can have a custom label, defaulting to its recorded key combination.
- Macros combining keyboard shortcuts, pauses and controller page changes, for example **go to Timeline → 50 ms → ⌘C**. A button can also change pages without sending a key.
- Guided physical-control identification, identified/pending indicators, automatic saving and configuration export.

The current interface is in Catalan. This is an independent project, not an official XPPen product.

## Build and run

The deployment target is **macOS 14 or later**. Install Xcode or Apple's command line developer tools with a macOS SDK and Swift compiler available through `xcrun`. There are no third-party runtime dependencies.

```sh
git clone https://github.com/lughdailh/pilot-pro-own.git
cd pilot-pro-own
./scripts/build-app.sh
open "$HOME/Library/Caches/PilotProOwnBuild/Pilot Pro Own.app"
```

The script compiles for the host architecture, signs the bundle ad hoc and copies it into `build/`. It stages the build in `~/Library/Caches/PilotProOwnBuild` to avoid cloud-provider bundle attributes. Set `PILOT_BUILD_DIR` to use another staging directory. If you have a signing identity, set `PILOT_CODESIGN_IDENTITY` to its name before building; no private certificate is required or included.

To install your local build, quit any running copy and copy **`~/Library/Caches/PilotProOwnBuild/Pilot Pro Own.app`** to **`/Applications/Pilot Pro Own.app`**. Changing the signing identity or application location can require granting permissions again.

## Configure the device

1. Connect the Pilot Pro by USB and open the app. It starts in monitoring mode with shortcut output disabled.
2. Select a control in the map, choose **Identificar aquest control**, then operate that physical control. Identifying one wheel direction also identifies its opposite.
3. Choose a profile and page. Click **Sense drecera** or an existing action to choose **Drecera de teclat** or **Canviar de pàgina**, or use **Crear seqüència** to combine actions. Edit **Etiqueta** to give an action a descriptive name.
4. Quit the official XPPen Pilot controller, grant Accessibility and any Input Monitoring access requested by macOS, then choose **Activar dreceres**.

Page changes update the assignments used at runtime. To also focus a Final Cut panel, include its keyboard shortcut in the sequence. Controller page selection does not automatically detect which Final Cut panel is focused. To copy Browser into Timeline, select Timeline, open **Gestionar pàgines → Copiar tota la configuració des de…**, choose Browser as the source, and use the button that names both source and destination. This replaces the destination settings while keeping its title and physical-device calibration.

A diagonal emits only its own action, never both cardinal actions. Its physical identification is derived from the calibrated cardinal axes, and new diagonals start unassigned.

Each page has its own dead zone, repeat interval, wheel-step filter and independent wheel polarity settings. The dead zone is measured independently on each axis; the preview shows the central area that ignores small movements. Existing configurations keep their previous threshold when displayed as a percentage.

Macros execute sequentially without interleaving their steps. An explicit page-change step continues the same sequence on the destination page; a manual page change, application change, disconnection, sleep or controller stop cancels it. If a referenced page is unavailable, execution stops before later keys are emitted. Page references survive renaming; when copied to a different profile, a corresponding page can be resolved by its title. A 50 ms delay is an initial value; some workflows need a longer pause.

## Configuration

The app saves to:

```text
~/Library/Application Support/Pilot Pro Own/configuration.json
```

Schema version 1 configurations migrate to version 2 pages with an automatic backup beside the original file. Hardware identification is shared across pages. Shortcuts, macros, labels and response settings are page-specific. No personal configuration or diagnostic logs are included in this repository.

## Tests

```sh
./scripts/test.sh
```

Core tests run without a connected controller. They cover input parsing and button transitions, sanitized USB report replay, profile/page migration and copying, percentage dead-zone boundaries, macro persistence, delay scheduling and cancellation. A GitHub Actions workflow template is provided in `docs/github-actions.example.yml`. To enable it, copy it to `.github/workflows/ci.yml` using a GitHub session with workflow-write permission. Automated CI is not enabled in this initial publication.

## Validation and current limits

The controller was physically identified and tested on an Apple Silicon Mac over USB. The original 24 signals were identified in the app; the four added diagonal signals are derived from those calibrated axes, and native UI checks covered page switching/copying, titles, shortcut recording and the macro editor. Emission of assigned shortcuts to Final Cut Pro was observed, but complete editor workflows and external-app macros have not all been independently verified.

Intel hardware, Bluetooth, haptics and long-running sleep/reconnect sessions are not validated. The official software sends per-wheel speed settings to the hardware; this app currently uses a software step filter and does not reproduce that hardware-speed setup. It sends no firmware-update or device-configuration reports.

## Source layout

| Folder | Contents |
| --- | --- |
| `App/` | SwiftUI app, HID access, settings and keyboard output |
| `App/Core/` | Protocol decoder, configuration schema and macro scheduler |
| `Assets/` | Original editable white/transparent controller illustration |
| `Sources/` | Read-only command-line HID probe |
| `Tests/` | Core checks and anonymous fixtures |
| `scripts/` | Build, test, probe and diagram-generation tools |

To run the read-only probe:

```sh
./scripts/build-probe.sh
./Diagnostics/pilot-probe 30
```

The probe matches only this device's vendor/product IDs and sends no output reports. Local probe output and build products are ignored by Git.

## Contributing

Issues and pull requests are welcome. Please include the macOS/app version, USB versus Bluetooth connection, affected physical control, and clear reproduction steps. Remove personal paths and configuration content before sharing logs. Run the core tests and native build before submitting changes. Distinguish simulated checks from physical-device testing.

Licensed under the [MIT license](LICENSE). XPPen and Pilot Pro are names of their respective owners.
