# Changelog

## Unreleased

### Changed

- **claude-code:** Updated to v2.1.269.
- **pi-coding-agent:** Updated to v0.85.1.
- **flake:** Migrated to the estate-wide flake-parts + import-tree convention.
  `flake.nix` now contains only inputs and `mkFlake` with import-tree; all
  output definitions live under `modules/flake/`. The formatter is now
  `nixfmt-rfc-style` (estate-wide). Added a `module-name-uniqueness` convention
  check that fails the build if `.nix` files appear at the top level of
  `modules/` outside the known roots.

- **netbird:** Updated to v0.78.1 (client and all six component overrides).
- **netbird-dashboard:** Updated to v2.92.0.
- **claude-code:** Updated to v2.1.261.
- **ray:** Updated to v3.2.11.
- **pi-coding-agent:** Updated to v0.85.0. Upstream added two new workspace
  packages (`chord`, `pi-server`) that the coding-agent now depends on; both
  are wired into the build. The vendored `models-data` snapshot was refreshed
  from the published `@earendil-works/pi-ai` 0.85.0 npm package.
- **deps:** nixpkgs base bumped to nixos-26.05 of 2026-09-03.
- **netbird:** Updated to v0.77.1.
- **pi-coding-agent:** Updated to v0.84.4. The vendored `models-data`
  snapshot was refreshed from the published `@earendil-works/pi-ai` package
  (the `data/` directory is not in the upstream git tag); the old snapshot
  still routed xAI models through `openai-completions`, which no longer type
  checks against the 0.84.x provider factories. The 0.84.4 patch bump type
  checks against the same snapshot, so it was left as is.
- **omp:** Updated to v18.0.11.
- **claude-code:** Updated to v2.1.251.
- **wails3:** Updated to v3.0.0-beta.16.
- **fontbase:** Updated to v2026.5.23.
- **zabbix74:** Updated to v7.4.14.
- **netbird-dashboard:** Updated to v2.91.1.
- **tinkerwell:** Updated to v5.17.3.

### Fixed

- **smoke tests:** `smoke-tinkerwell` was flaky under build load - it failed
  once with exit 139 during a parallel `nix flake check` and passed 7/7 when
  run alone. It started `Xvfb :99` by hand and waited with `sleep 2`, so a
  slow server start under load and a collision on the fixed display number
  (`__noChroot` shares `/tmp/.X11-unix` with the host) could both decide the
  result. It now uses `xvfb-run -a`, which waits until the server accepts
  connections and picks a free display. The assertion is unchanged and the
  exit status is still passed through, so a crashing binary still fails.
- **openjet:** Corrects #47, which left upstream's `cloud` extra
  (`keyring`, `litellm`) out on the reasoning that it only drives the
  "Slipstream" feature. That was wrong: `litellm` is the only runtime in
  openjet that accepts a `base_url`, so without it the tool cannot be pointed
  at an already-running OpenAI-compatible server - it fails with
  `LiteLLMUnavailableError`. Both extra dependencies are now normal runtime
  dependencies (nixpkgs has `keyring` 25.7.0 and `litellm` 1.86.0, both above
  upstream's minimums, so no constraint is relaxed) and the closure grows by
  about 137 MB. `pythonImportsCheck` imports `litellm`, `keyring` and
  `src.litellm_client`, and the new `smoke-openjet-litellm` check runs a
  one-shot chat against a loopback `base_url` to prove the runtime path is
  live.
- **openjet:** A NixOS host could not declare openjet's endpoint: after this
  package's state redirect there is a single config path and `save_config()`
  writes to it, so the file cannot belong to a generation. `load_config()` now
  reads a system layer underneath the user's file - `/etc/openjet/config.yaml`,
  overridable with `$OPENJET_SYSTEM_CONFIG`. It merges rather than replaces
  (upstream's loop returned the first candidate that existed): system
  `model_profiles` are always present and win a name collision, every other key
  is used only where the user's file has no value. `save_config()` still writes
  the user file only. New check `smoke-openjet-system-config`.
- **pi-coding-agent:** `pi` crashed on startup with
  `ERR_MODULE_NOT_FOUND: @earendil-works/pi-telemetry`. Only three of the six
  workspace packages the CLI needs at runtime were vendored into the output;
  `pi-telemetry`, `pi-protocol` and `pi-client` are now copied as well.

### Added

- **smoke tests:** `nix flake check` now executes the CLI packages, not
  just building them. Each `smoke-*` check runs the binary with a version
  command and requires the output to match a regex - exit status 0 alone
  does not pass, so a binary that prints its help instead of a version
  still goes red. Covers claude-code, pi, wails3, tinkerwell
  (on a virtual display), the netbird CLIs, netbird-dashboard (artifact
  check) and all zabbix server/proxy/agent variants. GUI/VST packages stay
  build-only; the list and the reasoning are in `pkgs/smoke-tests.nix`.
  Note: `smoke-tinkerwell` requires `--option sandbox relaxed` (Electron
  does not survive the strict build sandbox).
- **openjet:** Added v0.4.31. Local AI coding agent for OpenAI-compatible
  local runtimes, as a CLI (`openjet` and `open-jet`). First Python package in
  this set; built from the PyPI wheel because upstream's tags and its declared
  version disagree and PyPI ships no sdist. The `mcp` extra is included, the
  `cloud` extra (`keyring`, `litellm`, upstream's "Slipstream" feature) is
  deliberately left out. Upstream writes its config, its downloaded models and
  its token totals next to its own code, which under Nix is the read-only
  store - the install root is redirected to `$OPENJET_HOME`, else
  `$XDG_DATA_HOME/openjet`, else `~/.local/share/openjet`, and `load_config()`'s
  fallback to `./config.yaml` in the current working directory is removed so the
  configuration no longer depends on where the tool was started. The workflow
  runner, which upstream spawns as a bare `sys.executable -c …`, now gets the
  parent's `sys.path` passed down; without that `openjet workflow start` exited
  0 while the runner died immediately on a missing `yaml`. Telemetry stays as
  upstream ships it: opt-in, off until consent is granted. Upstream also
  advertises a Python SDK; it is not exposed here (this is an application, not a
  `python3Packages` entry), and `openjet --update` cannot work in the store -
  it reports "already up to date" whatever the case, so updating means bumping
  the package here.
- **herdr:** Added v0.8.2. Terminal workspace manager for AI coding agents.
  Builds from source on Linux (Rust + zig_0_15 for vendored libghostty-vt).
  Vendored from numtide/llm-agents.nix.
- **toneboosters-archive:** Added v2.1.8. Collection of 17 ToneBoosters audio
  plugins (VST2, VST3, standalone). Prebuilt x86_64-linux binaries, unfree.
- **vital:** Vendored from nixpkgs and bumped to v1.6.4 (ahead of nixpkgs at
  v1.5.5). This fixes a black screen on Wayland + Mesa 26. Added as
  `pkgs/by-name/vi/vital/package.nix` and auto-discovered by the by-name
  overlay.

### Removed

- **openjet:** Removed from the package set on the requester's preference.
  The package was not found broken - it built, and its three smoke tests
  passed. Its two consumers dropped it first (`lunitrixx/nix-config` #198,
  `nix-platform` #117), so nothing references `pkgs.openjet` any more. Gone
  with it: `pkgs/by-name/op/`, and the `smoke-openjet`,
  `smoke-openjet-litellm` and `smoke-openjet-system-config` checks.
- **omp:** Removed from the package set on the requester's preference. It was
  used on two hosts in `lunitrixx/nix-config` and is not in nixpkgs, so this
  removes it from those machines; the consumer dropped it first (#198). Gone
  with it: `pkgs/by-name/om/` and the `smoke-omp` check.
- **herdr:** Removed from the package set on the requester's preference. It
  had no consumer left - its Home Manager module was dropped from
  `lunitrixx/nix-config` earlier. Gone with it: `pkgs/by-name/he/` (including
  the vendored `build.zig.zon.nix` and `hashes.json`) and the `smoke-herdr`
  check.

