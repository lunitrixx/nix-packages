# The product of this flake: an overlay on top of nixpkgs that adds our
# packages. Apply in a consumer:
#   nixpkgs.overlays = [ inputs.nix-packages.overlays.default ];
# -> pkgs.netbird is ours, pkgs.mcp.<server> are our MCP servers;
#    pkgs.<anything we don't define> stays nixpkgs'.
#
# overlays.mcp adds only pkgs.mcp, for consumers that want the MCP servers
# without our versions of netbird, php85 and the other top-level packages.
{
  flake.overlays.default = import ../../pkgs/overlay.nix;
  flake.overlays.mcp = import ../../pkgs/mcp-overlay.nix ../../pkgs/mcp;
}
