# nixfmt-rfc-style estate-wide (was: plain nixfmt).
{
  perSystem = { pkgs, ... }: {
    formatter = pkgs.nixfmt-rfc-style;
  };
}
