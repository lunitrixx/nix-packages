# Vendored from nixpkgs pkgs/servers/monitoring/zabbix/versions.nix.
#
# Deltas vs nixpkgs:
#   - trimmed to only the v74 entry. This package set ships Zabbix 7.4
#     exclusively (package.nix assembles `zabbixFor "v74"`), so the v70/v60
#     pins were unreachable dead weight.
#   - v74 pinned to the version below. The hash is that release's upstream
#     zabbix-<version>.tar.gz sha256.
generic: {
  v74 = generic {
    version = "7.4.14";
    hash = "sha256-795fbxmJbwIAu1JF44ZgNWZyccex6EYm0mCV8kpvu0I=";
  };
}
