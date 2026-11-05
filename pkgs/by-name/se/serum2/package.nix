# Xfer Serum 2 for Linux, VST3 only, from the Xfer Records beta. Not in nixpkgs.
#
# The download sits behind an Xfer account login, so the archive cannot be
# fetched: requireFile makes the build stop with the instructions below until
# the file is in the store. The library list and the layout were measured from
# the real archive (2026-11-05): ldd of Serum2.so and its moduleinfo.json.
#
# Requires glibc >= 2.38 and an AVX2 CPU.
{
  lib,
  stdenv,
  requireFile,
  autoPatchelfHook,
  libSM,
  libICE,
  libX11,
  libXext,
  libxcb,
  libxcb-util,
  libxcb-cursor,
  libxcb-keysyms,
  libxkbcommon,
  freetype,
  glib,
  cairo,
  pango,
  harfbuzz,
  fontconfig,
  expat,
  curl,
  zstd,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "serum2";
  version = "2.1.5-beta-2026-10-31";

  src = requireFile {
    name = "Serum2_Linux_Beta_26-10-31_bbcd310_x86_64.tar.xz";
    sha256 = "55c6c38abcbeafaa318d5074f6d917065bd70f4bf249cd70e3af732250c5827a";
    message = ''
      Xfer Serum 2 for Linux is a beta behind an Xfer Records login (you must own
      Serum 2 and have an Xfer account). Download the Linux beta archive from the
      Xfer Records site (xferrecords.com, beta forum), then:

        cp <downloaded-file> Serum2_Linux_Beta_26-10-31_bbcd310_x86_64.tar.xz
        nix-store --add-fixed sha256 Serum2_Linux_Beta_26-10-31_bbcd310_x86_64.tar.xz

      The archive must have sha256 55c6c38abcbeafaa318d5074f6d917065bd70f4bf249cd70e3af732250c5827a.
      Do not send the file itself to the repository maintainers.
    '';
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    libSM
    libICE
    libX11
    libXext
    libxcb
    libxcb-util
    libxcb-cursor
    libxcb-keysyms
    libxkbcommon
    freetype
    glib
    cairo
    pango
    harfbuzz
    fontconfig
    expat
    curl
    zstd
    (lib.getLib stdenv.cc.cc) # libstdc++, libgcc_s
  ];

  dontBuild = true;

  # Needs a manually downloaded file: excluded from `checks` (see
  # modules/flake/checks/packages.nix), still exposed in `packages`.
  passthru.requiresManualDownload = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/vst3
    cp -r Serum2.vst3 $out/lib/vst3/

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
