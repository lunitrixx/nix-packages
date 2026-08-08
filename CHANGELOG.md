# Changelog

## Unreleased

### Changed

- **netbird:** Updated to v0.76.2.
- **pi-coding-agent:** Updated to v0.84.1 (added telemetry, protocol, client workspace
  build steps; new baseten + qwen-token-plan-individual model data).
- **omp:** Updated to v17.2.10.
- **claude-code:** Updated to v2.1.224.
- **wails3:** Updated to v3.0.0-beta.5.
- **fontbase:** Updated to v2026.5.23.
- **zabbix74:** Updated to v7.4.13.
- **netbird-dashboard:** Updated to v2.90.9.
- **tinkerwell:** Updated to v5.17.2.

### Fixed

- **pi-coding-agent:** `pi` crashed on startup with
  `ERR_MODULE_NOT_FOUND: @earendil-works/pi-telemetry`. Only three of the six
  workspace packages the CLI needs at runtime were vendored into the output;
  `pi-telemetry`, `pi-protocol` and `pi-client` are now copied as well.

### Added

- **toneboosters-archive:** Added v2.1.8. Collection of 17 ToneBoosters audio
  plugins (VST2, VST3, standalone). Prebuilt x86_64-linux binaries, unfree.
- **vital:** Vendored from nixpkgs and bumped to v1.6.4 (ahead of nixpkgs at
  v1.5.5). This fixes a black screen on Wayland + Mesa 26. Added as
  `pkgs/by-name/vi/vital/package.nix` and auto-discovered by the by-name
  overlay.

