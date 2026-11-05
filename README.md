# nix-packages

A custom Nix package set, modelled on nixpkgs. It is an **overlay on top of
nixpkgs**: consumers get our packages where we define them, and everything else
falls through to the original nixpkgs. Two kinds of packages live here:

- packages **pinned ahead of the nixpkgs channel** (vendored from nixpkgs and
  version-pinned, so there's no wait for a channel bump), and
- packages **nixpkgs doesn't ship at all**.

First resident: **NetBird**. nixpkgs lagged behind upstream releases, holding
back both the VPN client and the self-hosted server components - and the reverse
proxy isn't in nixpkgs at all. All of it is built here, version-matched.

## How it works (the nixpkgs `by-name` mechanism and the `mcp` set)

```
pkgs/
├── overlay.nix                         # the complete overlay: by-name + mcp
├── by-name-overlay.nix                 # mirrors nixpkgs' pkgs/top-level/by-name-overlay.nix
├── mcp-overlay.nix                     # pkgs/mcp/<name> -> pkgs.mcp.<name>
├── mcp/
│   └── forgejo-mcp/                    # npm tarball + committed runtime package-lock.json
└── by-name/
    ├── cr/crowdsec-openresty-bouncer/
    ├── fo/fontbase/
    ├── ne/netbird/                     # one source tree -> any component via componentName
    ├── ne/netbird-management/          # { netbird }: netbird.override { componentName = …; }
    ├── ne/netbird-signal/  ne/netbird-relay/  ne/netbird-proxy/
    ├── ne/netbird-ui/  ne/netbird-upload/  ne/netbird-dashboard/
    ├── ph/php85/
    ├── ra/ray/
    ├── se/serum2/                      # Xfer Serum 2 beta; the archive is fetched by hand (requireFile)
    ├── ta/tabby-terminal/
    ├── ti/tinkerwell/
    ├── to/toneboosters-archive/
    ├── wa/wails3/
    ├── wi/win-iso-remaster/
    └── za/zabbix74/                    # package.nix + versions.nix + vendored component files
```

The shard is the first two letters of the package name. Each directory holds a
`package.nix`; there is no central list to register a package in.

`by-name-overlay.nix` reads every `pkgs/by-name/<shard>/<name>/package.nix` and
loads it with `final.callPackage` - exactly like nixpkgs. So a `package.nix` is
a normal nixpkgs-style file (its `{ stdenv, lib, … }` arguments resolve from the
overlaid set), and sibling references like `{ netbird }` resolve to *our*
netbird, keeping every component version-matched. Because it's a plain overlay,
anything we don't define stays as nixpkgs provides it.

MCP servers live in `pkgs/mcp/<name>/package.nix` instead, without a shard.
`mcp-overlay.nix` exposes them as one set, `pkgs.mcp.<name>`, so each server
keeps its upstream name without shadowing a nixpkgs package of the same name:
`pkgs.mcp.forgejo-mcp` is ours, while `pkgs.forgejo-mcp` stays nixpkgs'
unrelated Go server. A new MCP server is a new directory under `pkgs/mcp/`.

| Attribute | Binary | Role |
|-----------|--------|------|
| `netbird` | `netbird` | VPN client / agent |
| `netbird-management` | `netbird-mgmt` | control plane + API |
| `netbird-signal` | `netbird-signal` | peer signalling |
| `netbird-relay` | `netbird-relay` | rendezvous relay |
| `netbird-proxy` | `netbird-proxy` | reverse proxy (not in nixpkgs) |
| `netbird-ui` | `netbird-ui` | desktop tray GUI |
| `netbird-upload` | `netbird-upload` | debug-bundle upload-server |
| `netbird-dashboard` | static SPA | web console |

## Packages

Everything this repository defines today; anything else stays nixpkgs'.
Packages are auto-discovered from `pkgs/by-name/` and `pkgs/mcp/` - a new
`package.nix` is a new package. The last two columns show the name in the
flake outputs (see [Usage](#usage)).

| Package | What it is | `packages.<system>` | `legacyPackages.<system>` |
|---------|------------|---------------------|---------------------------|
| NetBird (8) | NetBird VPN, one source tree, version-matched - see the table above | `netbird`, `netbird-management`, … | same |
| Zabbix 7.4 | an attrset of derivations; version and hash pinned in `versions.nix` | `zabbix74-<component>`, e.g. `zabbix74-agent2` | `zabbix74.<component>`, e.g. `zabbix74.agent2` |
| CrowdSec OpenResty bouncer | Lua remediation component for OpenResty (not in nixpkgs); ships Lua + config templates, no binary | `crowdsec-openresty-bouncer` | same |
| PHP 8.5 | pinned ahead of the channel, built with nixpkgs' `generic.nix` (see below) | `php85` | same |
| Wails v3 | CLI, a Go module netbird-ui builds against (not in nixos-26.05) | `wails3` | same |
| Windows 11 ISO remaster | remasters a Windows 11 ISO (see below) | `win-iso-remaster` | same |
| Ray, Tinkerwell, FontBase | unfree AppImage desktop apps (x86_64-linux) | `ray`, `tinkerwell`, `fontbase` | same |
| ToneBoosters archive | unfree plugin archive, VST2 + VST3 (x86_64-linux), stable 2.1.8; plugins only, no headless entry point | `toneboosters-archive` | same |
| Xfer Serum 2 | VST3, Linux beta (x86_64-linux, glibc >= 2.38, AVX2); the archive needs an Xfer account, so it is added to the store by hand (see the build message) | `serum2` | same |
| Tabby terminal | built from the .deb (x86_64-linux); deliberately not `tabby`, which is TabbyML in nixpkgs | `tabby-terminal` | same |
| Forgejo MCP server | SquareCows, npm `@ric_/forgejo-mcp`; dependencies pinned by a committed lock file | `mcp-forgejo-mcp` | `mcp.forgejo-mcp` |

## Usage

Add it as a flake input. Name the input `lunitrixx`, so everything from here
reads `inputs.lunitrixx.*`. Let its `nixpkgs` follow yours, so no second
nixpkgs is fetched.

In a flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    lunitrixx = {
      url = "github:lunitrixx/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

In devenv (`devenv.yaml`):

```yaml
inputs:
  lunitrixx:
    url: github:lunitrixx/nix-packages
    inputs:
      nixpkgs:
        follows: nixpkgs
```

Then pick one of three ways.

**Single packages through the input.** Every other package stays as nixpkgs
has it, and the code shows where the package comes from:

```nix
inputs.lunitrixx.packages.${pkgs.stdenv.hostPlatform.system}.netbird
inputs.lunitrixx.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zabbix74.agent2
inputs.lunitrixx.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mcp.forgejo-mcp

# devenv, e.g. an MCP server for the agents:
command = lib.getExe inputs.lunitrixx.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mcp.forgejo-mcp;
```

`packages` is flat, so nested packages appear there as `zabbix74-agent2` and
`mcp-forgejo-mcp`. `legacyPackages` keeps the nesting.

**The whole overlay.** Our packages replace nixpkgs' in `pkgs`:

```nix
nixpkgs.overlays = [ inputs.lunitrixx.overlays.default ];
# pkgs.netbird and pkgs.mcp.forgejo-mcp are ours; everything else stays nixpkgs'
```

**Only the MCP set.** `overlays.mcp` adds `pkgs.mcp` and changes nothing else:

```nix
nixpkgs.overlays = [ inputs.lunitrixx.overlays.mcp ];
# pkgs.mcp.forgejo-mcp is ours; pkgs.netbird stays nixpkgs'
```

In devenv, an overlay is listed on the input (`overlays: [ default ]` or
`overlays: [ mcp ]`) instead of in `nixpkgs.overlays`.

Build a package without adding the input:

```sh
nix build github:lunitrixx/nix-packages#netbird
nix build github:lunitrixx/nix-packages#mcp.forgejo-mcp   # from legacyPackages
```

After a change here, update the consumer's lock: `nix flake update lunitrixx`
in a flake, `devenv update lunitrixx` in devenv.

## Build / test

```sh
nix build .#netbird .#netbird-management .#netbird-dashboard
nix flake check   # builds every package we define (except manual-download ones) and runs the smoke tests
nix fmt           # formats every .nix file (nixfmt-tree)
```

The smoke tests in `modules/flake/checks/smoke-tests.nix` execute the CLI
packages and match their output, so a binary that builds but does not run
fails the check. GUI apps and packages without a headless entry point are only
built; the file lists which ones and why.

## Bump a version

The agent skill `version-update` (`.pi/skills/version-update`) checks every
package under `pkgs/by-name/` and `pkgs/mcp/` for a newer upstream version and
bumps it. By hand:

1. set `version`
2. refresh the source `hash`: `nurl <repo-url> <tag>` for a Git source,
   `nix store prefetch-file <url>` for a `fetchurl` tarball
3. build once; copy the real `vendorHash` / `npmDepsHash` from the mismatch error

`netbird` (`pkgs/by-name/ne/netbird/package.nix`): one bump updates the client
and every server component at once. `netbird-dashboard` is bumped on its own.

`zabbix74`: bump the single `version` and `hash` in
`pkgs/by-name/za/zabbix74/versions.nix` (a `fetchurl` tarball, so use
`nix store prefetch-file`). That re-pins every component. Leave the vendored
component files untouched.

`mcp.forgejo-mcp` (`pkgs/mcp/forgejo-mcp`): the npm tarball has no lock file,
so a new version also needs a new `package-lock.json`. Bumping only `version`
and `hash` keeps the old dependencies. Unpack the new tarball, remove `devDependencies` and `scripts`
from its `package.json` (`jq 'del(.devDependencies, .scripts)'`), run
`npm install --package-lock-only --ignore-scripts`, and copy the lock next to
`package.nix`. The `hash` is `npm view @ric_/forgejo-mcp@<version> dist.integrity`.

## PHP 8.5

`php85` (`pkgs/by-name/ph/php85/package.nix`) is pinned ahead of the channel at
8.5.12. It calls nixpkgs' `generic.nix` with our version, hash and `patches`,
so `php85.withExtensions` and the `php85Packages` set work as in nixpkgs.

Add an upstream security fix as one entry in `patches`:

```nix
patches = [
  (fetchpatch {
    url = "https://github.com/php/php-src/commit/<sha>.patch";
    hash = lib.fakeHash; # build once, then copy the `got:` hash from the error
  })
];
```

`lib.fakeHash` needs `lib` in the argument list of `package.nix`. Copy the
`got:` hash from the mismatch error into `hash`.

Take the next release by setting `version` and `hash`. The hash is the SRI
`sha256` of `https://www.php.net/distributions/php-<version>.tar.bz2` (nixpkgs'
`generic.nix` fetches the bz2, not the xz), which `nix store prefetch-file --json
<url>` prints. It must match the `sha256` in the release feed
`https://www.php.net/releases/index.php?json&version=8.5`.
The `smoke-php85` assertion derives the version from the package, so the
smoke test needs no change.

## Windows 11 ISO remaster

`win-iso-remaster` (`pkgs/by-name/wi/win-iso-remaster`) writes a copy of a
Windows 11 ISO that boots UEFI without the "Press any key to boot from CD or
DVD" prompt and installs Pro without an edition list (`sources/ei.cfg`). The
source ISO is never modified; the output lands next to it as
`*_pro_noprompt.iso` (`*_noprompt.iso` with `--noprompt-only`), or at the path
given with `-o FILE`.

```sh
win-iso-remaster Windows11.iso                    # rebuild with ei.cfg
win-iso-remaster --noprompt-only Windows11.iso    # patch only the UEFI boot image
```

The rebuild follows the dockur/windows recipe and writes UDF, which the 8 GB
`install.wim` needs. It needs free space of twice the ISO size. `--pid KEY`
writes `sources/PID.txt`; `--no-bios-prompt` removes `boot/bootfix.bin`, which
is not verified on hardware.

## License

The package descriptions (Nix expressions) are [MIT](./LICENSE). This does not
apply to the packaged software, which carries its own upstream licenses.
