# Xfer Serum 2 for Linux, VST3 only, from the Xfer Records beta. Not in nixpkgs.
#
# The download sits behind an Xfer account login, so the archive cannot be
# fetched: requireFile makes the build stop with the instructions below until
# the file is in the store. Everything after that point is unverified until a
# real download has been built - the archive layout and the library list
# (taken from the NixOS Discourse thread 79429, tested by its author on
# NixOS with REAPER 7.88, not with this package) may differ.
#
# Requires glibc >= 2.38 and an AVX2 CPU.
{
  lib,
  stdenv,
  requireFile,
  unzip,
  autoPatchelfHook,
  xorg,
  libxkbcommon,
  xkbutils,
  freetype,
  glib,
  cairo,
  pango,
  harfbuzz,
  fontconfig,
  expat,
  curl,
  openssl,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "serum2";
  version = "2.0.0-beta";

  src = requireFile {
    name = "Serum2_Linux_beta.zip";
    sha256 = lib.fakeSha256;
    message = ''
      Xfer Serum 2 for Linux is a beta behind an Xfer Records login (you must own
      Serum 2 and have an Xfer account). Download the Linux beta from
      https://xferrecords.com/forums/serum/serum-2-linux-beta/ and then:

        cp <downloaded-file> Serum2_Linux_beta.zip
        nix-store --add-fixed sha256 Serum2_Linux_beta.zip
        sha256sum Serum2_Linux_beta.zip

      Send the printed digest to the repository maintainers (or open a pull
      request that sets the sha256 attribute of pkgs/by-name/se/serum2/package.nix)
      so the package can be built from it. Do not send the file itself.
    '';
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];

  buildInputs = [
    xorg.libSM
    xorg.libICE
    xorg.libX11
    xorg.libXext
    xorg.libXfixes
    xorg.libxcb
    xorg.xcbutil
    xorg.xcbutilcursor
    xorg.xcbutilkeysyms
    libxkbcommon
    xkbutils
    freetype
    glib
    cairo
    pango
    harfbuzz
    fontconfig
    expat
    curl
    openssl
    (lib.getLib stdenv.cc.cc) # libstdc++, libgcc_s
  ];

  dontBuild = true;

  # Needs a manually downloaded file: excluded from `checks` (see
  # modules/flake/checks/packages.nix), still exposed in `packages`.
  passthru.requiresManualDownload = true;

  installPhase = ''
    runHook preInstall

    bundle=$(find . -type d -name Serum2.vst3 | head -n 1)
    if [ -z "$bundle" ]; then
      echo "no Serum2.vst3 bundle in the archive" >&2
      exit 1
    fi
    mkdir -p $out/lib/vst3
    cp -r "$bundle" $out/lib/vst3/

    runHook postInstall
  '';

  meta = {
    description = "Xfer Serum 2 wavetable synthesizer (VST3, Linux beta)";
    homepage = "https://xferrecords.com";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
})
