# Vendored from nixpkgs pkgs/servers/monitoring/zabbix/versions.nix.
#
# Deltas vs nixpkgs:
#   - trimmed to only the v74 entry. This package set ships Zabbix 7.4
#     exclusively (package.nix assembles `zabbixFor "v74"`), so the v70/v60
#     pins were unreachable dead weight.
#   - v74 pinned to 7.4.13. The hash is the upstream zabbix-7.4.13.tar.gz sha256.
generic: {
  v74 = generic {
    version = "7.4.13";
    hash = "sha256-68T7BUr5GbEjYi/uqdTDmXEc8FB+8ZPi3tdnE6gO48Y=";
  };
}
