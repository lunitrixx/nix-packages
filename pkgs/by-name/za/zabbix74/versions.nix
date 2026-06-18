# Vendored from nixpkgs pkgs/servers/monitoring/zabbix/versions.nix.
#
# Deltas vs nixpkgs:
#   - trimmed to only the v74 entry. This package set ships Zabbix 7.4
#     exclusively (package.nix assembles `zabbixFor "v74"`), so the v70/v60
#     pins were unreachable dead weight.
#   - v74 pinned to 7.4.10 (our target version) instead of the pinned
#     nixpkgs' 7.4.11. The hash is the upstream zabbix-7.4.10.tar.gz sha256.
generic: {
  v74 = generic {
    version = "7.4.10";
    hash = "sha256-hVdgC5Nmby+JsQjpmYl3dA4I7DXyoCXaMLdggi6Wa/o=";
  };
}
