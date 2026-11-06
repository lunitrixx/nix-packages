# Architecture

A custom Nix package set, modelled on nixpkgs. It is an overlay on top of nixpkgs: consumers get our
packages where we define them, and anything we do not define falls through to nixpkgs. Two kinds of
packages live here:

- packages pinned ahead of the nixpkgs channel (vendored from nixpkgs and version-pinned, so there is
  no wait for a channel bump), and
- packages nixpkgs does not ship at all.

## Layout

```text
flake.nix                    inputs, mkFlake, the import-tree root; never defines an output itself
modules/flake/               flake-level flake-parts modules, auto-imported by import-tree
  systems.nix                target systems (x86_64-linux, aarch64-linux)
  overlays.nix               overlays.default and overlays.mcp (the product)
  _base.nix                  nixpkgs + overlay + allowUnfree; a helper, skipped by import-tree
  legacy-packages.nix        legacyPackages: ours + nixpkgs fall-through
  packages.nix               packages: only ours, attrsets flattened
  formatter.nix              formatter: nixfmt-tree, formats the whole tree
  convention.nix             checks.module-name-uniqueness
  checks/packages.nix        checks = packages, minus manual-download packages
  checks/smoke-tests.nix     checks.smoke-*: execute the CLI packages
pkgs/
  overlay.nix                the complete overlay (by-name + mcp)
  by-name-overlay.nix        mirrors nixpkgs' pkgs/top-level/by-name-overlay.nix
  mcp-overlay.nix            pkgs/mcp/<name>/package.nix -> pkgs.mcp.<name>
  by-name/<shard>/<name>/package.nix
  mcp/<name>/package.nix
```

The flake follows the flake-parts + import-tree convention: one file per output under
`modules/flake/`, nesting there is free, and a path starting with `_` is skipped. The repository has
no class tree (`modules/nixos/`, `modules/homeManager/`), so `flake.nix` has no class imports. The
check `module-name-uniqueness` fails when a `.nix` file sits under `modules/` outside
`modules/flake/`.

## How the overlay works

`pkgs/by-name-overlay.nix` is the mechanism nixpkgs uses (`pkgs/top-level/by-name-overlay.nix`): it
reads every `pkgs/by-name/<shard>/<name>/package.nix` and loads it with `final.callPackage`. A
`package.nix` is therefore a normal nixpkgs-style file whose arguments resolve from the overlaid set,
and sibling references such as `{ netbird }` resolve to our netbird. The shard is the first two
letters of the name.

`pkgs/mcp-overlay.nix` does the same for `pkgs/mcp/<name>/package.nix` (no shard) and exposes the
result as one set, `pkgs.mcp.<name>`, so MCP servers keep their upstream names without shadowing a
top-level nixpkgs package (decision: `design-docs/0002-mcp-set.md`). `pkgs/overlay.nix` combines
both overlays; `overlays.default` and `_base.nix` import it.

## Flake outputs

| Output | Content |
| :--- | :--- |
| `overlays.default` | The complete overlay. `pkgs.netbird` becomes ours, the rest stays nixpkgs'. |
| `overlays.mcp` | Only `pkgs.mcp`, for consumers that want the MCP servers without our top-level packages. |
| `legacyPackages.<system>` | nixpkgs with our overlay and `allowUnfree` (ours + fall-through). |
| `packages.<system>` | Only our packages, flat: an attrset package such as `zabbix74` becomes `zabbix74-<sub>`, `pkgs.mcp.<name>` becomes `mcp-<name>`. Packages not available on the system are dropped (`lib.meta.availableOn`). |
| `checks.<system>` | Every entry of `packages` except those with `passthru.requiresManualDownload`, the smoke tests and the module convention check. |
| `formatter.<system>` | `nixfmt-tree`. |

The flake's own outputs build with `config.allowUnfree = true` (`_base.nix`). The exposed overlays
are plain overlays, so consumers set their own `allowUnfree`.

## Smoke tests

`modules/flake/checks/smoke-tests.nix` runs each CLI package with a version command and matches the
output, so a binary that builds but does not run fails the check. GUI apps and packages without a
headless entry point are only built; the file lists which ones and why.

## Consumers

Consumers add the flake as an input named `lunitrixx` with `inputs.nixpkgs.follows` set to their
nixpkgs, and use single packages through the input, `overlays.default` or `overlays.mcp` (see
`README.md`, Usage). Known consumers: `nix-images` (`pkgs.zabbix74.<component>`) and
`headfirst-msp/devenv-base` (`mcp.forgejo-mcp` for the Forgejo MCP server).

Decisions: `design-docs/index.md`.
