# Packaging

Rules for adding and bumping packages. The mechanism behind them is in `ARCHITECTURE.md`.

## Where a package goes

- `pkgs/by-name/<shard>/<name>/package.nix`: the layout nixpkgs uses. `<shard>` is the first two
  letters of the name, the file is `package.nix`, not `default.nix`. It is found automatically.
- MCP servers go to `pkgs/mcp/<name>/package.nix` with the upstream name and become
  `pkgs.mcp.<name>` (flat in `packages`: `mcp-<name>`).
- Check the sibling packages before writing a new one and follow their shape.

## Vendoring from nixpkgs

- Copy the package's `package.nix` from nixpkgs as it is and keep the deltas minimal: the pinned
  `version` and hashes, plus what nixpkgs does not have.
- Document each delta in a comment at the top of the file.
- Always pin a specific version and hash. Never track a branch or `latest`.

## Multi-component packages

One source tree with many binaries, like NetBird, keeps a single parameterised parent
(`componentName ? "..."`) and one small by-name file per component doing
`netbird.override { componentName = ...; }`, as nixpkgs does. `final.callPackage` makes
`{ netbird }` resolve to our package, so all components stay version-matched, and one bump of the
parent updates the client and every server component. `netbird-dashboard` is a separate source and
is bumped on its own.

## Attrset-valued packages

`zabbix74` is the exception to the per-component rule (decision:
`design-docs/0001-zabbix74-attrset.md`). Its `package.nix` reproduces nixpkgs' `zabbixFor "v74"`
block and returns `recurseIntoAttrs (...)`: one by-name entry whose value is an attrset of
derivations (`.server-pgsql`, `.web`, `.agent2`, ...). Use this shape only when a consumer needs the
attrset access. Keep the vendored component files (`server.nix`, `web.nix`, ...) verbatim and confine
deltas to `versions.nix` and the `package.nix` assembly.

## Unfree, platform-restricted and manual-download packages

- The flake's own `packages` and `checks` build with `allowUnfree = true`; consumers set their own.
- `packages` drops anything not `lib.meta.availableOn` the current system, so `x86_64-linux`-only
  packages do not break `aarch64-linux` checks.
- A package whose source needs a manual download (login-gated vendors, for example `serum2`) uses
  `requireFile` and sets `passthru.requiresManualDownload = true`. It stays in `packages` but is left
  out of `checks`, because no build machine can fetch the file. Its smoke test, if any, must not need
  the file. With the file in the local store (`nix-store --add-fixed`), `nix build .#<name>` works.

## Overlay argument names

The exposed overlays name their arguments `final`/`prev`. nixpkgs uses `self`/`super` internally,
but `nix flake check` requires `final`/`prev` for a flake overlay.

## Bumping a version

Version bumps change dependencies and need approval. The skill `version-update`
(`.agents/skills/version-update/`) checks every package for a newer upstream version and bumps it.
By hand:

1. Set `version`.
2. Refresh the source `hash`: `nurl <repo-url> <tag>` for a Git source,
   `nix store prefetch-file <url>` for a `fetchurl` tarball.
3. Build once and copy the real `vendorHash` / `npmDepsHash` from the mismatch error.
4. Run `nix flake check`.

Package-specific steps:

- `zabbix74`: bump the single `version` and `hash` in `pkgs/by-name/za/zabbix74/versions.nix` (a
  `fetchurl` tarball, so `nix store prefetch-file`). That re-pins every component. Leave the vendored
  component files untouched.
- `mcp.forgejo-mcp`: the npm tarball has no lock file, so a new version also needs a new
  `package-lock.json` (steps in `README.md`, Bump a version).
- `php85`: version, hash and security patches are described in `README.md`, PHP 8.5.

A bump here reaches consumers only after they update the input (`nix flake update lunitrixx` or
`devenv update lunitrixx`).
