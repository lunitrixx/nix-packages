# Changelog

## Unreleased

### Changed

- **netbird:** Updated to v0.74.2.
- **omp:** Updated to v16.3.7.
- **claude-code:** Updated to v2.1.201.
- **tinkerwell:** Updated to v5.17.0.
- **stalwart:** Enabled `enterprise` compile-time feature in `buildFeatures`.
  The feature compiles enterprise code into the binary but requires a license
  key to activate - without one, Stalwart runs as the standard open-source
  edition.
- **netbird-dashboard:** Updated to v2.90.2.
- **pi-coding-agent:** Updated to v0.80.3.
- **omp:** Updated to v16.2.12.
- **claude-code:** Updated to v2.1.197. Switched source from GCS to GitHub
  Releases as Anthropic migrated binary hosting.

### Added

- **vital:** Vendored from nixpkgs and bumped to v1.6.4 (ahead of nixpkgs at
  v1.5.5). This fixes a black screen on Wayland + Mesa 26. Added as
  `pkgs/by-name/vi/vital/package.nix` and auto-discovered by the by-name
  overlay.
- **stalwart:** Stalwart Mail Server v0.16.11 (ahead of nixpkgs at v0.15.5).
  Added as `pkgs/by-name/st/stalwart/package.nix` and auto-discovered by the
  by-name overlay.
