# Changelog

## Unreleased

### Changed

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

- **stalwart:** Stalwart Mail Server v0.16.11 (ahead of nixpkgs at v0.15.5).
  Added as `pkgs/by-name/st/stalwart/package.nix` and auto-discovered by the
  by-name overlay.
