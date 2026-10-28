# The full package set (ours + nixpkgs fall-through), exposed the same way
# nixpkgs itself exposes it:
#   nix build  nix-packages#netbird       (ours)
#   nix build  nix-packages#hello         (from nixpkgs)
#
# The base set (nixpkgs + overlay + allowUnfree) comes from _base.nix, shared
# with packages.nix and checks/smoke-tests.nix.
{
  inputs,
  lib,
  config,
  ...
}:
{
  flake.legacyPackages = lib.genAttrs config.systems (
    system:
    import ./_base.nix {
      inherit inputs;
      inherit system;
    }
  );
}
