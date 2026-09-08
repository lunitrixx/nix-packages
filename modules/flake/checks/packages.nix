# Every package we define is also a check, so `nix flake check` builds them
# all. `config.packages` is the perSystem packages attrset, already merged from
# the module that defines it.
{
  perSystem =
    { config, ... }:
    {
      checks = config.packages;
    };
}
