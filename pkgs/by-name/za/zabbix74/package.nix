# Vendored from nixpkgs pkgs/servers/monitoring/zabbix/ (component files
# server.nix / agent.nix / agent2.nix / web.nix / proxy.nix copied verbatim;
# versions.nix trimmed to only the v74 entry - see its header) plus the
# `zabbixFor` assembly from nixpkgs' pkgs/top-level/all-packages.nix, pinned
# to v7.4.
#
# Deltas vs nixpkgs:
#   - the assembly lives here instead of all-packages.nix (we have no
#     all-packages); it callPackages the SIBLING component files (./*.nix) so
#     they resolve to our overlaid set. Version + source hash are pinned in
#     ./versions.nix (v74).
#   - `lib.recurseIntoAttrs` instead of the bare `recurseIntoAttrs` that
#     all-packages.nix uses: `recurseIntoAttrs` has been removed from the
#     top-level pkgs set in our pinned nixpkgs (nixos-26.05), so the bare form
#     only resolves via a deprecation shim. Same function, current spelling.
{ lib, callPackages }:
let
  zabbixFor = version: rec {
    agent = (callPackages ./agent.nix { }).${version};
    proxy-mysql = (callPackages ./proxy.nix { mysqlSupport = true; }).${version};
    proxy-pgsql = (callPackages ./proxy.nix { postgresqlSupport = true; }).${version};
    proxy-sqlite = (callPackages ./proxy.nix { sqliteSupport = true; }).${version};
    server-mysql = (callPackages ./server.nix { mysqlSupport = true; }).${version};
    server-pgsql = (callPackages ./server.nix { postgresqlSupport = true; }).${version};
    web = (callPackages ./web.nix { }).${version};
    agent2 = (callPackages ./agent2.nix { }).${version};

    # backwards compatibility (matches nixpkgs)
    server = server-pgsql;
  };
in
lib.recurseIntoAttrs (zabbixFor "v74")
