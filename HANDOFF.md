# HANDOFF — ClevoTune

## 1. Goal
- A single-file Windows tool (`.exe` + equivalent `.cmd`) for the owner's Clevo P775DM3-G (i7-8700K + RTX 3080 Laptop, DEV_24DC, vBIOS 94.04.46.00.15, driver 621.12): live sensors, GPU tuning and custom EC fan curves. It replaces Clevo Control Center and MSI Afterburner on this laptop.

## 2. Current status
- **v1.7.0** (`main`, released as `v1.7.0`; the release workflow succeeded, including `validate.ps1`, `power-limits.ps1` and `runtime.ps1` on Windows). It adds fan curves to profiles (see below); not yet confirmed on the user's hardware. `main` also has later docs-only commits (README/HANDOFF updates and new per-tab screenshots in `docs/`, personal info redacted) that are not in the v1.7.0 zip; they ship with the next release. Previously **v1.6.6** (`main` + release v1.6.5, assets `ClevoTune.v1.6.5.{zip,exe,cmd}`). Earlier versions were tested on the user's hardware with these features working; v1.6.5 has automated Windows validation but still needs hardware confirmation:
  - sensors
  - fan curves (temperature/load, ClevoFanControl import/export)
  - core/memory offsets and clock lock
  - mVolt+ core voltage offset (`--core-vdemand` exit 0)
  - automatic PawnIO and mVolt+ install, tray, start with Windows, 6 languages
- v1.7.0: a profile now also stores `fans` (array of `{index, mode, source, fixed, points[{t,p}]}`, same shape as `cfg.fans`) via `Get-FanSnapshot` (`src/app.ps1:340`, also used by `Save-Config`). `Load-ProfileFans` (`:1312`) restores it, optionally for one fan only; `Load-ProfileToSliders` calls it, so the Load button, tray apply and on-open/startup profile restore curves (and Load applies them to the fans immediately, unlike sliders). Profiles without `fans` (older configs) are skipped. Tray menu (`Build-TrayMenu :2140`) has submenus "Load CPU/GPU curve from profile" (Tag = `fanIndex|profileName`). If `cfcGrid` is on, loaded off-grid curves are converted to the 40–85 grid.
- v1.6.3 (NVML reconnect after a GPU reset) has not yet been confirmed on the user's PC.
- v1.6.4 added read-only power-limit recheck after an external BIOS override, honest unverified mVolt+ readback, fresh readback on refresh, and Center overlay position. Windows regression/markup/C# 5 checks pass locally; release workflow repeats them before publishing.
- User screenshot shows BIOS override active with 160 W default and 185 W active. Actual draw above 160 W under load remains unverified.

- v1.6.5 keeps dispatcher polling alive during mVolt+/network waits and serializes tuning/update operations. Manual fans fall back to EC without their thermal feedback; overheat protection wins. Reset/startup invalidates applied voltage/lock indicators. Fresh power readback warns on either direction of mismatch (>1 W).
- Overlay positions now include Center, Top center and Bottom center, with a saved monitor DeviceName and primary fallback on disconnect. Screen pixels are converted to WPF coordinates.
- `tests/runtime.ps1` covers real harmless subprocess/loopback HTTP delays/timeouts, UI-operation guards, thermal policy and monitor persistence. Run after `tests/validate.ps1`; no real GPU/EC writes are performed.

## 3. Key decisions (don't re-debate)
- **Hardware access:** PawnIO (signed driver) with the official modules `LpcACPIEC.bin` and `IntelMSR.bin`, not WinRing0, which Defender blocks.
- **Fans:** EC commands from the Tuxedo/ClevoFanControl protocol (see `src/core.cs:89`, `ClevoEc`). There are only **2 fans** (1 = CPU, 2 = GPU); index 3 returns junk.
- **GPU APIs:** NVML for sensors and clock lock; NVAPI Pstates20 (version 0x11C94) for offsets; mVolt+ CLI for voltage and power (`src/app.ps1:665`).
- **mVolt+ copy:** kept in `<app folder>\mVolt+\mVolt+.exe` + `version.txt`, auto-updated from GitHub `b00nz/mVolt` at most every 12 h (`src/app.ps1:630`). The user asked for this.
- **Languages:** English is the base. Keys are English text; translations live in `src/lang.py` → `Language/*.lng` (en-us, pt, fr, es, de, it).
- **Script C#:** C# 5 / .NET Framework 4.x only, because it is compiled by Windows PowerShell's Add-Type. The C# source is embedded ASCII-escaped by `build.py`.
- **Versioning:** the user requires a **version bump on every change**. File names follow `ClevoTune (vX.Y.Z).ext`.

## 4. Tried and failed (don't retry)
- **Raising TGP above 160 W without a BIOS override.** These earlier attempts did not raise the enforced limit:
  - NVML `SetPowerManagementLimit` → Not Supported
  - NVAPI ClientPowerPolicies → 0 policies, invalid argument
  - mVolt+ `--power` → "Power limit is unavailable"
  - mVolt+ `--power-cap-watts 175` → accepted, but 160 W is still enforced
- **Decimals in mVolt+ `--power`** → "numeric option could not be parsed" (integers only).
- **Creating releases/tags from this session** → HTTP 403 for both the REST API and tag push. Use the workflow dispatch instead (below).

## 5. Files that matter
- `src/app.ps1` — the app. Key places:
  - UI logic, timer `:2000`
  - tuning: `Init-Tuning :918`, `Apply-Tuning :1028`
  - profiles `:1303` (`Profile-Text`, `Load-ProfileFans`, `Fill-Profiles`), tray menu `:2140`
  - setup `:487`, languages `:120`, autostart `:1270`, fan curve UI `:1479`, `.cfg` import `:1815` (line numbers approximate)
- `src/core.cs` — C# core:
  - `PawnIo :27`, `ClevoEc :89`, `NvApi :314`, `Hw :562`
  - NVML reconnect `:751`, `ReadGpu :774`, fan `Control :877`
- `src/main.xaml` — WPF window. Texts are English keys.
- `src/lang.py` — translation table (key, pt, fr, es, de, it), `.lng` file generator.
- `src/launcher/` — net48 WinExe launcher (requireAdministrator, embeds the script, runs PowerShell hidden).
- `build.py` — builds `ClevoTune.cmd`, `Language/*.lng`, `dist/*.exe|cmd|zip`. Needs Python 3 + .NET SDK.
- `.github/workflows/release.yml` + `.github/release_notes.py` — builds and publishes a release from `main`.
- `README.md` (user docs, English), `CHANGELOG.md` (one entry per version).

## 6. Next steps
0. Ask the user to test v1.7.0 on hardware: save a profile (Save as…), change the curves, Load it and confirm the curves return; try the tray entries "Load CPU/GPU curve from profile". Old profiles have no `fans` until re-saved.
1. Ask the user to confirm v1.6.3 GPU readings after a GPU reset: the log should show `NVML: … reconnecting` / `reconnected`.
2. After applying/changing the external mVolt+ BIOS override, use **Re-check power limits**. It clears `cfg.powerMax`/`cfg.powerLocked`, queries NVML/mVolt+ and never applies tuning. Confirm both reported limits and measured draw under load.
3. License: GPL-3.0 (see `LICENSE`).
4. For every release:
   - bump `$AppVersion` in `src/app.ps1:3`
   - add a `CHANGELOG.md` entry
   - run `python build.py`
   - commit and push `main`
   - run `gh api -X POST repos/j0p3s/Clevo-tuner/actions/workflows/release.yml/dispatches -f ref=main -f 'inputs[version]=X.Y.Z'`

## 7. Open questions / gotchas
- **Release notes:** the v1.7.0 release body only says "See CHANGELOG.md" because `.github/release_notes.py` did not match the `## v1.7.0` header (older entries use `## [x.y.z] - date`). Use the bracketed format in the next CHANGELOG entry, or fix the script.
- **Fan count (decided: not changing):** the app deliberately has a fixed CPU fan + GPU fan (see section 3). Auto-detecting 3-fan models was discussed and declined by the user; a naive probe would report junk fan 3 as present because `DetectFans` only checks that the EC reads do not throw. Do not implement unless asked.
- **Screenshots:** `docs/screenshot-{tuning,fans,overlay,settings}.png` are v1.6.6 UI. They were redacted by painting over the profile name in the Auto-apply chip and the install path in the mVolt+ line; redo this for any new screenshots.
- Local Windows validation is available (no physical GPU verification performed):
  - `powershell -NoProfile -STA -File tests/validate.ps1`
  - `powershell -NoProfile -File tests/power-limits.ps1`
  - The local machine has no .NET SDK; the release workflow builds the full executable. Previous validation methods:
  - `pwsh` `Parser.ParseFile`
  - a net48 C# 5 compile
  - a WPF markup build (needs the official .NET SDK with WindowsDesktop targets)
- The user then tests on hardware and pastes log lines.
- **GitHub asset names:** spaces and parentheses become dots. The files inside the zip keep `ClevoTune (vX.Y.Z)`.
- **Line endings:** `ClevoTune.cmd` is stored with `-text` (CRLF); batch breaks with LF.
- **Config:** `%APPDATA%\ClevoTune\config.json`. `powerLocked` / `powerMax` are keyed by driver version.
- **Scheduled task:** enabled startup is refreshed to the current version path on launch. Elevated interactive logon, 15 s delay, battery support, StartWhenAvailable, unlimited runtime; registration/removal errors terminate and are logged. `tests/startup.ps1` validates task construction without registering a real task.
- **Profiles with curves:** older profiles have no `fans` property; code must test `PSObject.Properties.Name -contains 'fans'`. The v1.7.0 change was made from a Linux session without PowerShell/.NET, so it still needs `tests/validate.ps1` (the release workflow runs it) and a hardware check: save a profile, change curves, Load, confirm the curves return; try the tray CPU/GPU curve entries.
- **Clevo Control Center** must be closed, or it overrides the fan curves.
