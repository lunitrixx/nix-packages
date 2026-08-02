# Changelog

## Unreleased

### Changed

- **netbird:** Updated to v0.76.0.
- **zabbix74:** Updated to v7.4.13.
- **omp:** Updated to v17.2.4.
- **claude-code:** Updated to v2.1.220.
- **pi-coding-agent:** Updated to v0.83.0.
- **netbird-dashboard:** Updated to v2.90.9.
- **tinkerwell:** Updated to v5.17.2.
- **wails3:** Updated to v3.0.0-beta.1 (from alpha2.117). Added `modRoot = "v3"` for new beta module layout.

### Added

- **toneboosters-archive:** Added v2.1.8. Collection of 17 ToneBoosters audio
  plugins (VST2, VST3, standalone). Prebuilt x86_64-linux binaries, unfree.
- **vital:** Vendored from nixpkgs and bumped to v1.6.4 (ahead of nixpkgs at
  v1.5.5). This fixes a black screen on Wayland + Mesa 26. Added as
  `pkgs/by-name/vi/vital/package.nix` and auto-discovered by the by-name
  overlay.

