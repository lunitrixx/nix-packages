# Changelog

## Unreleased

### Changed

- **netbird:** Updated to v0.77.1.
- **pi-coding-agent:** Updated to v0.84.2.
- **omp:** Updated to v18.0.4.
- **claude-code:** Updated to v2.1.241.
- **wails3:** Updated to v3.0.0-beta.12.
- **fontbase:** Updated to v2026.5.23.
- **zabbix74:** Updated to v7.4.13.
- **netbird-dashboard:** Updated to v2.91.1.
- **tinkerwell:** Updated to v5.17.2.

### Fixed

- **pi-coding-agent:** `pi` crashed on startup with
  `ERR_MODULE_NOT_FOUND: @earendil-works/pi-telemetry`. Only three of the six
  workspace packages the CLI needs at runtime were vendored into the output;
  `pi-telemetry`, `pi-protocol` and `pi-client` are now copied as well.

### Added

- **herdr:** Added v0.8.2. Terminal workspace manager for AI coding agents.
  Builds from source on Linux (Rust + zig_0_15 for vendored libghostty-vt).
  Vendored from numtide/llm-agents.nix.
- **toneboosters-archive:** Added v2.1.8. Collection of 17 ToneBoosters audio
  plugins (VST2, VST3, standalone). Prebuilt x86_64-linux binaries, unfree.
- **vital:** Vendored from nixpkgs and bumped to v1.6.4 (ahead of nixpkgs at
  v1.5.5). This fixes a black screen on Wayland + Mesa 26. Added as
  `pkgs/by-name/vi/vital/package.nix` and auto-discovered by the by-name
  overlay.

