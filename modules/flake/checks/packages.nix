# Every package we define is also a check, so `nix flake check` builds them
# all - except those marked `passthru.requiresManualDownload`: their source
# is a requireFile that no build machine can fetch, so they stay in `packages`
# only. `config.packages` is the perSystem packages attrset, already merged
# from the module that defines it.
{
  perSystem =
    { config, lib, ... }:
    {
      checks = lib.filterAttrs (_: drv: !(drv.passthru.requiresManualDownload or false)) config.packages;
    };
}
