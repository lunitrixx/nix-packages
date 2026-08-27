# Changelog

## Unreleased

### Changed

- **netbird:** Updated to v0.77.1.
- **pi-coding-agent:** Updated to v0.84.3. The vendored `models-data`
  snapshot was refreshed from the published `@earendil-works/pi-ai` package
  (the `data/` directory is not in the upstream git tag); the old snapshot
  still routed xAI models through `openai-completions`, which no longer type
  checks against the 0.84.3 provider factories.
- **omp:** Updated to v18.0.6. v18.0.7 exists as a tag but has no release
  assets, so 18.0.6 is the newest buildable release.
- **claude-code:** Updated to v2.1.247.
- **wails3:** Updated to v3.0.0-beta.14.
- **fontbase:** Updated to v2026.5.23.
- **zabbix74:** Updated to v7.4.14.
- **netbird-dashboard:** Updated to v2.91.1.
- **tinkerwell:** Updated to v5.17.2.

### Fixed

- **pi-coding-agent:** `pi` crashed on startup with
  `ERR_MODULE_NOT_FOUND: @earendil-works/pi-telemetry`. Only three of the six
  workspace packages the CLI needs at runtime were vendored into the output;
  `pi-telemetry`, `pi-protocol` and `pi-client` are now copied as well.

### Added

- **smoke tests:** `nix flake check` now executes the CLI packages, not
  just building them. Each `smoke-*` check runs the binary with a version
  command and requires the output to match a regex - exit status 0 alone
  does not pass, so a binary that prints its help instead of a version
  still goes red. Covers claude-code, omp, pi, wails3, herdr, tinkerwell
  (on a virtual display), the netbird CLIs, netbird-dashboard (artifact
  check) and all zabbix server/proxy/agent variants. GUI/VST packages stay
  build-only; the list and the reasoning are in `pkgs/smoke-tests.nix`.
  Note: `smoke-tinkerwell` requires `--option sandbox relaxed` (Electron
  does not survive the strict build sandbox).
- **herdr:** Added v0.8.2. Terminal workspace manager for AI coding agents.
  Builds from source on Linux (Rust + zig_0_15 for vendored libghostty-vt).
  Vendored from numtide/llm-agents.nix.
- **toneboosters-archive:** Added v2.1.8. Collection of 17 ToneBoosters audio
  plugins (VST2, VST3, standalone). Prebuilt x86_64-linux binaries, unfree.
- **vital:** Vendored from nixpkgs and bumped to v1.6.4 (ahead of nixpkgs at
  v1.5.5). This fixes a black screen on Wayland + Mesa 26. Added as
  `pkgs/by-name/vi/vital/package.nix` and auto-discovered by the by-name
  overlay.

