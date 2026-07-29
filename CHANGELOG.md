# Changelog

## Unreleased

### Changed

- **netbird:** Updated to v0.75.1. The UI component now builds with a
  two-phase process (pnpm frontend + CGo) and Wails3/GTK4 support,
  re-enabling the netbird-ui package that was broken since 0.75.0.
- **zabbix74:** Updated to v7.4.12.
- **omp:** Updated to v17.1.8.
- **claude-code:** Updated to v2.1.214.
- **pi-coding-agent:** Updated to v0.80.10.
- **netbird-dashboard:** Updated to v2.90.8.
- **tinkerwell:** Updated to v5.17.1.

### Added

- **toneboosters-archive:** Added v2.1.8. Collection of 17 ToneBoosters audio
  plugins (VST2, VST3, standalone). Prebuilt x86_64-linux binaries, unfree.
- **vital:** Vendored from nixpkgs and bumped to v1.6.4 (ahead of nixpkgs at
  v1.5.5). This fixes a black screen on Wayland + Mesa 26. Added as
  `pkgs/by-name/vi/vital/package.nix` and auto-discovered by the by-name
  overlay.

