# nixfmt-tree: `nix fmt` without arguments formats every .nix file in the tree.
# Bare nixfmt (nixfmt-rfc-style is now only an alias for it) reads stdin when
# called without paths, so plain `nix fmt` failed with "unexpected end of input".
{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-tree;
    };
}
