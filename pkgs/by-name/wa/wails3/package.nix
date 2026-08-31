# Vendored from nixpkgs (pkgs/by-name/wa/wails3/package.nix).
#
# Needed by netbird-ui since 0.75.0+ which uses Wails3. Not yet available
# in the nixos-26.05 channel, so we carry it here until the channel catches up.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  wrapGAppsHook4,
  webkitgtk_6_0,
}:

buildGoModule (finalAttrs: {
  pname = "wails3";
  version = "3.0.0-beta.16";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "wailsapp";
    repo = "wails";
    tag = "v${finalAttrs.version}";
    hash = "sha256-TNEs3iST2k/eD0sNgjyUWR3/fwG2WjByuB+9N90Ph9A=";
  };

  proxyVendor = true;
  vendorHash = "sha256-bDSbGoEGaFMEyfKFQx2ZYBovTMmdl+QvwBeCH4gj4uI=";
  modRoot = "v3";

  subPackages = [ "cmd/wails3" ];

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ webkitgtk_6_0 ];

  # Propagate so consumers (netbird-ui) get pkg-config, wrapGAppsHook4, and
  # webkitgtk_6_0 automatically when they add wails3 to nativeBuildInputs.
  propagatedBuildInputs = [
    pkg-config
    wrapGAppsHook4
  ];
  depsTargetTargetPropagated = [ webkitgtk_6_0 ];

  meta = {
    description = "Build desktop applications using Go & Web Technologies, v3 beta";
    homepage = "https://wails.io";
    license = lib.licenses.mit;
    mainProgram = "wails3";
    platforms = lib.platforms.unix;
  };
})
