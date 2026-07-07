# Vendored from nixpkgs pkgs/by-name/vi/vital/package.nix.
# Deltas from nixpkgs:
#   - Version bumped to 1.6.4 (fixes black screen on Wayland + Mesa 26)
#   - fetchurl + unzip instead of fetchzip (new ZIP format breaks fetchzip)
#   - sourceRoot = "VitalInstaller"
#   - mesa + wayland in buildInputs + appendRunpaths so all binaries
#     can dlopen libEGL/libwayland-egl at runtime. Standalone wrapper
#     also sets __EGL_VENDOR_LIBRARY_DIRS; plugins inherit host env.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  alsa-lib,
  libjack2,
  curl,
  libx11,
  libsm,
  libice,
  libGL,
  freetype,
  mesa,
  wayland,
  zenity,
  makeDesktopItem,
  copyDesktopItems,
  imagemagick,
  unzip,
}:
let
  icon = fetchurl {
    url = "https://vital.audio/images/apple_touch_icon.png";
    hash = "sha256-NZ/AQ2gjBXUPUj3ITbowD7HuxRmEDuATOWidLqLNrww=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "vital";
  version = "1.6.4";

  src = fetchurl {
    url = "https://builds.vital.audio/VitalAudio/vital/${
      builtins.replaceStrings [ "." ] [ "_" ] finalAttrs.version
    }/VitalInstaller.zip";
    hash = "sha256-XOyMsON98F7Bbryu+TQrvyHBf1T4fGIAva4VlwVVT0I=";
  };
  sourceRoot = "VitalInstaller";

  desktopItems = [
    (makeDesktopItem {
      type = "Application";
      name = "vital";
      desktopName = "Vital";
      comment = "Spectral warping wavetable synth";
      icon = "Vital";
      exec = "Vital";
      categories = [
        "Audio"
        "AudioVideo"
      ];
    })
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
    copyDesktopItems
    imagemagick
    unzip
  ];

  buildInputs = [
    alsa-lib
    (lib.getLib stdenv.cc.cc)
    curl
    freetype
    libGL
    libice
    libjack2
    libsm
    libx11
    mesa
    wayland
  ];

  # autoPatchelfHook only adds RPATH for direct NEEDED dependencies.
  # mesa + wayland are dlopen'd by BGFX at runtime, so we append them.
  appendRunpaths = lib.makeLibraryPath [
    mesa
    wayland
    curl
    libjack2
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icons/hicolor/128x128/apps
    magick ${icon} -resize 128x128 $out/share/icons/hicolor/128x128/apps/Vital.png

    # copy each output to its destination (individually)
    mkdir -p $out/{bin,lib/{clap,vst,vst3}}
    for f in bin/Vital lib/{clap/Vital.clap,vst/Vital.so,vst3/Vital.vst3}; do
      cp -r $f $out/$f
    done

    wrapProgram $out/bin/Vital \
      --set __EGL_VENDOR_LIBRARY_DIRS "${mesa}/share/glvnd/egl_vendor.d" \
      --prefix PATH : "${
        lib.makeBinPath [
          zenity
        ]
      }"

    runHook postInstall
  '';

  meta = {
    description = "Spectral warping wavetable synth";
    homepage = "https://vital.audio/";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [
      PowerUser64
      l1npengtul
    ];
    mainProgram = "Vital";
  };
})
