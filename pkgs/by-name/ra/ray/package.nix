{
  lib,
  fetchurl,
  appimageTools,
}:
let
  version = "3.2.10";
  src = fetchurl {
    url = "https://ray-app.s3.eu-west-1.amazonaws.com/ray-app-updates-v3/stable/ray-${version}-latest-linux-x86_64.AppImage";
    hash = "sha256-fua2wG61+Qto9yRw77EHZZP41EuPaS7xucOMl7+9WtE=";
  };
  appimageContents = appimageTools.extractType2 {
    pname = "ray";
    inherit version src;
  };
in
appimageTools.wrapType2 rec {
  pname = "ray";
  inherit version src;
  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/ray.desktop $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop --replace-fail 'Exec=AppRun' 'Exec=${meta.mainProgram}'
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';
  meta = {
    mainProgram = "ray";
    description = "Desktop debugging app by Spatie";
    homepage = "https://myray.app";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
