{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  alsa-lib,
  fontconfig,
  freetype,
  curl,
  libGL,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "toneboosters-archive";
  version = "2.1.8";

  src = fetchurl {
    url = "https://www.toneboosters.com/downloads/TB_Archive_v${finalAttrs.version}_linux.tar.gz";
    hash = "sha256-aJ9itDLrd0/jzqdJX3aX0RlhjqA7Pg/0BsJVYikNsZg=";
    curlOptsList = [
      "--user-agent"
      "Mozilla/5.0 (X11; Linux x86_64)"
    ];
  };

  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    alsa-lib
    fontconfig
    freetype
    curl
    libGL
    (lib.getLib stdenv.cc.cc) # libatomic, libstdc++
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/vst $out/lib/vst3

    # VST2 plugins
    cp vst/*.so $out/lib/vst/

    # VST3 bundles
    for dir in vst3/*.vst3; do
      cp -r "$dir" $out/lib/vst3/
    done

    # Standalone applications
    for f in app/*; do
      name=''${f#app/}
      cp "$f" "$out/bin/$name"
      chmod +x "$out/bin/$name"
    done

    runHook postInstall
  '';

  meta = {
    description = "ToneBoosters Archive - collection of 17 professional audio plugins (VST2, VST3, standalone)";
    homepage = "https://www.toneboosters.com";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "TB_Equalizer_v4";
  };
})
