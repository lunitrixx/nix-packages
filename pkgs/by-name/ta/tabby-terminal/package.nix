# Not in nixpkgs. Named tabby-terminal because nixpkgs' `tabby` is TabbyML, an
# unrelated AI coding assistant this overlay must not shadow. Built from the
# .deb rather than the AppImage: appimageTools runs apps in bubblewrap, whose
# no_new_privs makes sudo fail in every Tabby shell.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libsecret,
  libxkbcommon,
  nspr,
  nss,
  pango,
  udev,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
}:
stdenv.mkDerivation rec {
  pname = "tabby-terminal";
  version = "1.0.238";

  src = fetchurl {
    url = "https://github.com/Eugeny/tabby/releases/download/v${version}/tabby-${version}-linux-x64.deb";
    hash = "sha256-XqK5qoTytc3LmMt+lL09kt5IyWJUqYtSvy0fMKUtHRw=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libsecret
    libxkbcommon
    nspr
    nss
    pango
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
  ];

  runtimeDependencies = [ (lib.getLib udev) ];

  dontBuild = true;
  dontConfigure = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/opt $out/bin
    cp -r opt/Tabby $out/opt/tabby
    cp -r usr/share $out/share
    # Prebuilt node modules for other platforms or musl do not load here.
    find $out/opt/tabby -name '*.node' \( -name '*darwin*' -o -name '*win32*' -o -name '*arm*' -o -name '*musl*' \) -delete
    substituteInPlace $out/share/applications/tabby.desktop \
      --replace-fail 'Exec=/opt/Tabby/tabby' 'Exec=tabby'
    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/opt/tabby/tabby $out/bin/tabby \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "--ozone-platform-hint=auto"
  '';

  meta = {
    mainProgram = "tabby";
    description = "Terminal, SSH and serial client";
    homepage = "https://tabby.sh";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
