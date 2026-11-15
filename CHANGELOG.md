# Changelog

All notable changes to ClevoTune. Versions follow [Semantic Versioning](https://semver.org/).

## v1.7.0
- Saving a profile now also stores the fan curves (mode, source, fixed % and points of both fans). Loading a profile, applying it from the tray, and the on-open/startup profile restore its curves too. Older profiles without curves keep the current ones.
- Tray right-click menu: **Load CPU curve from profile** and **Load GPU curve from profile**.

## v1.6.6
- Harden Windows Task Scheduler startup: elevated interactive logon, 15-second delay, battery support, unlimited runtime and missed-start recovery.
- Safely encode CMD launch paths and set the working directory for both launchers.
- Report task creation/removal failures and refresh enabled startup tasks when opening a new app version.

## [1.6.5] - 2026-11-07
### Fixed
- Slow mVolt+ commands and update downloads keep the UI dispatcher, sensor polling and fan-control timer running. Concurrent tuning operations are blocked; timed-out subprocesses are terminated.
- Manual fan modes return their fan to EC automatic control when its temperature feedback is unavailable. Detected overheating still takes priority and forces full cooling.
- Voltage and clock-lock values are marked unknown at startup and after a GPU reset. A reset during tuning invalidates the result; unknown voltage settings are applied again instead of skipped.
- Power targets are checked against fresh readback for NVML/NVAPI and mVolt+, with a warning for differences greater than 1 W in either direction. Logs distinguish requested and enforced watts.
### Added
- Overlay monitor selection, including primary-display fallback when a saved display is disconnected, plus **Top center** and **Bottom center** positions.
- Regression checks for responsive subprocess/network waits, timeouts, operation serialization, resets during tuning, thermal failover and monitor selection.

## [1.6.4] - 2026-11-07
### Added
- **Center** overlay position, saved with the other overlay settings and maintained when the overlay resizes.
- **Re-check power limits** clears remembered power restrictions and reads current NVML/mVolt+ limits after an external BIOS override, without applying tuning.
### Fixed
- The power slider can include a currently observed enforced limit above the stock range; mVolt+'s theoretical maximum is not used.
- Missing or invalid mVolt+ power readback is reported as unverified instead of treating the requested wattage as enforced or caching a ceiling.
- Refresh readback queries mVolt+ again; cached mVolt+ readback is discarded after automatic NVML reconnection.
### Documentation
- Clarified that the earlier 160 W ceiling applied to tests without a BIOS override, and that configured limits and measured power draw are separate.

## [1.6.3] - 2026-11-07
### Fixed
- GPU readings after a driver/GPU reset (e.g. mVolt+ "Restart GPU" or resume from sleep): out-of-range values such as a 998277 MHz clock are rejected, and ClevoTune reconnects to NVML (and NVAPI) automatically when temperature and clock stay unreadable.
- GPU temperature falls back to the EC reading (marked "EC" on the card) while NVML is unavailable, and the safety temperature check uses it too.

## [1.6.2] - 2026-11-07
### Fixed
- A profile power value above the measured maximum of the card is reduced to that maximum, so it is not retried at every start.

## [1.6.1] - 2026-11-07
### Changed
- mVolt+ power: the enforced limit is verified with `--status`. When the card won't go above its default, the slider maximum is capped there for that driver version.
- Lowering the power limit uses `--power-cap-watts`; returning to the default uses `--return-to-percentage`.
### Fixed
- PawnIO modules already present are copied to the shared cache in `%APPDATA%\ClevoTune\modules`.

## [1.6.0] - 2026-11-07
### Added
- mVolt+ is kept in a `mVolt+` folder next to ClevoTune, installed automatically and updated from its GitHub releases (checked at most every 12 hours, or with **Check for mVolt+ updates**).
### Removed
- "Locate mVolt+…" and "Download mVolt+" buttons (replaced by the automatic local copy).

## [1.5.2] - 2026-11-07
### Fixed
- PawnIO modules are also stored in `%APPDATA%\ClevoTune\modules`, so a new program folder doesn't download them again.

## [1.5.1] - 2026-11-07
### Fixed
- mVolt+: whole-number `--power` percentage (decimals were rejected).
- mVolt+: power and voltage are sent in separate calls; `--power-cap-watts` is tried when the percentage control is unavailable.
- A power value equal to what the card already enforces is not sent again.
- The power slider is disabled if mVolt+ also refuses the power limit.

## [1.5.0] - 2026-11-07
### Added
- mVolt+ integration through its command line: power limit when the NVIDIA driver blocks NVML/NVAPI.
- **Core voltage offset (mVolt+)** slider (`--core-vdemand`), stored in profiles.
- Settings panel for mVolt+.

## [1.4.3] - 2026-11-07
### Changed
- If both NVML and the NVAPI power target refuse the power limit, it is marked as locked for that driver version and the slider is disabled.

## [1.4.2] - 2026-11-07
### Changed
- The NVAPI power target is always tried when NVML refuses, and the driver's full answer is logged.

## [1.4.1] - 2026-11-07
### Added
- NVAPI power target (client power policies) as a fallback when NVML answers *Not Supported*.

## [1.4.0] - 2026-11-07
### Changed
- English is the base language: code, interface and `.lng` keys are in English; Portuguese is a translation.
- Old Portuguese-keyed `.lng` files are converted automatically (backup `.old`).

## [1.3.4] - 2026-11-07
### Fixed
- Fans tab: the live status no longer overlaps the Preset box.
- Sensor card titles no longer overlap the extra value (e.g. "GPU CLOCK" / "MEM 7001").

## [1.3.3] - 2026-11-07
### Added
- "Start with Windows (at sign-in)" option also in Settings and in the tray menu, kept in sync.

## [1.3.2] - 2026-11-07
### Added
- README.md with full documentation.

## [1.3.1] - 2026-11-07
### Changed
- Languages moved to editable `Language\*.lng` files; custom languages supported; "Open language folder" button.

## [1.3.0] - 2026-11-07
### Added
- Multi-language interface: Portuguese, English, French, Spanish, German, Italian.

## [1.2.1] - 2026-11-07
### Added
- The last saved profile is applied automatically when the app opens (option, on by default).

## [1.2.0] - 2026-11-07
### Added
- `.exe` launcher (administrator, no console, Task Scheduler friendly).
- Load-based fan curves (CPU, GPU or max load) with load smoothing.

## [1.1.1] - 2026-11-07
### Removed
- The non-existent third fan; only the CPU and GPU fans are shown.

## [1.1.0] - 2026-11-07
### Added
- ClevoFanControl `userfancurve.cfg` import/export, fixed 40–85 °C grid, **Save curves** button.

## [1.0.0] - 2026-11-06
### Added
- First release: sensor dashboard, GPU tuning (core/memory offsets, power limit, clock limit), profiles, EC fan curves, overlay, tray, start with Windows, automatic PawnIO setup.

[1.6.3]: https://github.com/j0p3s/Clevo-tuner/releases/tag/v1.6.3
[1.6.2]: https://github.com/j0p3s/Clevo-tuner/releases/tag/v1.6.2
