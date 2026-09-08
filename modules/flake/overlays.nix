# The product of this flake: an overlay on top of nixpkgs that adds our
# packages. Apply in a consumer:
#   nixpkgs.overlays = [ inputs.nix-packages.overlays.default ];
# -> pkgs.netbird is ours; pkgs.<anything we don't define> stays nixpkgs'.
{
  flake.overlays.default = import ../../pkgs/by-name-overlay.nix ../../pkgs/by-name;
}
