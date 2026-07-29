# NetBird - all components (self-hosted server + client + desktop UI), built
# from one source tree.
#
# Deltas from nixpkgs:
#   * pinned version + hashes (kept ahead of the nixpkgs channel);
#   * added the `proxy` component (reverse proxy, not packaged in nixpkgs);
#   * two-phase build for the UI component: pnpm frontend with dummy Wails3
#     bindings in preBuild, then CGo build with //go:embed of dist/.
{
  stdenv,
  lib,
  nixosTests,
  nix-update-script,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  runCommand,
  pkg-config,
  gtk4,
  webkitgtk_6_0,
  libsoup_3,
  libx11,
  libxcursor,
  libxxf86vm,
  versionCheckHook,
  nodejs,
  pnpm,
  fetchPnpmDeps,
  cacert,
  sqlite,
  zstd,
  netbird-management,
  netbird-proxy,
  netbird-relay,
  netbird-signal,
  netbird-ui,
  netbird-upload,
  componentName ? "client",
}:
let
  version = "0.75.1";

  src = fetchFromGitHub {
    owner = "netbirdio";
    repo = "netbird";
    tag = "v${version}";
    hash = "sha256-QRCP/P0wDD0y3p+WqUHRhj2mtrEPgwSK6dVD2zKNBlo=";
  };

  # pnpm dependencies for the UI frontend (only fetched when building ui).
  uiPnpmDeps =
    if componentName != "ui" then
      null
    else
      let
        frontendSrc = runCommand "netbird-ui-frontend-src" { } ''
          mkdir -p $out
          cp -r ${src}/client/ui/frontend/* $out/
        '';
      in
      fetchPnpmDeps {
        pname = "netbird-ui-frontend";
        inherit version;
        src = frontendSrc;
        pnpmLock = "${frontendSrc}/pnpm-lock.yaml";
        hash = "sha256-T4E4GJgsoMZnLokJRuDm1L43OrYF99PLF4x/4HRIB4E=";
        fetcherVersion = 4;
      };

  availableComponents = {
    client = {
      module = "client";
      binaryName = "netbird";
      license = lib.licenses.bsd3;
      versionCheckProgramArg = "version";
      hasCompletion = true;
    };
    ui = {
      module = "client/ui";
      binaryName = "netbird-ui";
      license = lib.licenses.bsd3;
    };
    upload = {
      module = "upload-server";
      binaryName = "netbird-upload";
      license = lib.licenses.bsd3;
    };
    management = {
      module = "management";
      binaryName = "netbird-mgmt";
      license = lib.licenses.agpl3Only;
      versionCheckProgramArg = "--version";
      hasCompletion = true;
    };
    signal = {
      module = "signal";
      binaryName = "netbird-signal";
      license = lib.licenses.agpl3Only;
      hasCompletion = true;
    };
    relay = {
      module = "relay";
      binaryName = "netbird-relay";
      license = lib.licenses.agpl3Only;
    };
    proxy = {
      module = "proxy/cmd/proxy";
      binaryName = "netbird-proxy";
      license = lib.licenses.bsd3;
    };
  };
  component = availableComponents.${componentName};
in
buildGoModule (finalAttrs: {
  pname = "netbird-${componentName}";
  inherit version src;

  vendorHash = "sha256-KVGCV89qGHrg2GQVw6MnftQswbdihcqozptjf5vs5BA=";

  overrideModAttrs = final: prev: {
    name = "netbird-${finalAttrs.version}-go-modules";
  };

  proxyVendor = true;

  nativeBuildInputs = [
    installShellFiles
    cacert
  ] ++ lib.optionals (componentName == "ui") [
    pkg-config
    nodejs
    pnpm
    sqlite
    zstd
  ];

  buildInputs = lib.optionals (stdenv.hostPlatform.isLinux && componentName == "ui") [
    gtk4
    webkitgtk_6_0
    libsoup_3
    libx11
    libxcursor
    libxxf86vm
  ];

  subPackages = [ component.module ];

  tags = lib.optionals (componentName == "ui") [ "production" ];

  env = lib.optionalAttrs (componentName == "ui") {
    CGO_ENABLED = "1";
  };

  ldflags = [
    "-s"
    "-w"
    "-X github.com/netbirdio/netbird/version.version=v${finalAttrs.version}"
    "-X main.builtBy=nix"
  ];

  doCheck = false;

  postPatch = ''
    # make it compatible with systemd's RuntimeDirectory
    substituteInPlace client/cmd/root.go \
      --replace-fail 'unix:///var/run/netbird.sock' 'unix:///var/run/netbird/sock'
  ''
  + lib.optionalString (componentName == "ui") ''
    # Remove the Wails3 Vite plugin - we cannot run "wails3 generate bindings"
    # in the Nix sandbox. The plugin generates event bridge code; at runtime
    # the Go binary provides these via the embedded frontend.
    substituteInPlace client/ui/frontend/vite.config.ts \
      --replace-fail "wails(\"./bindings\")" "/* wails plugin disabled for Nix build */"
  '';

  preBuild = lib.optionalString (componentName == "ui") ''
    # --- Replicate pnpmConfigHook logic manually, but in client/ui/frontend ---

    export HOME=$(mktemp -d)

    # Suppress pnpm 11's own package-manager version management
    export pnpm_config_pm_on_fail=ignore
    export pnpm_config_trust_lockfile=true

    STORE_PATH=$(mktemp -d)
    tar --zstd -xf ${uiPnpmDeps}/pnpm-store.tar.zst -C "$STORE_PATH"
    chmod -R +w "$STORE_PATH"

    # Reconstruct SQLite database from dump (fetcherVersion=4 format)
    if [ -f "$STORE_PATH/v11/index.db.sql" ]; then
      sqlite3 "$STORE_PATH/v11/index.db" < "$STORE_PATH/v11/index.db.sql"
      rm "$STORE_PATH/v11/index.db.sql"
    fi

    pnpm config set store-dir "$STORE_PATH"

    # Prevent hard linking on file systems without clone support
    pnpm config set package-import-method clone-or-copy

    # --- Create dummy Wails3 bindings so TypeScript imports resolve ---
    bindingsDir=client/ui/frontend/bindings/github.com/netbirdio/netbird/client/ui
    mkdir -p $bindingsDir/services $bindingsDir/i18n $bindingsDir/preferences $bindingsDir/updater

    cat > $bindingsDir/services/index.js << 'SVCEOF'
    export {
      Autostart, Compat, Connection, DaemonFeed, Debug,
      I18n, Networks, Preferences, Profiles, ProfileSwitcher,
      Restrictions, Session, SetConfigParams, Settings, Status,
      UILog, Update, Version, WindowManager,
    } from "./models.js";
    SVCEOF

    cat > $bindingsDir/services/models.js << 'MDLEOF'
    export const Autostart = {};
    export const Compat = {};
    export const Config = {};
    export const Connection = {};
    export const DaemonFeed = {};
    export const Debug = {};
    export const DebugBundleResult = {};
    export const I18n = {};
    export const Network = {};
    export const Networks = {};
    export const PeerStatus = {};
    export const Preferences = {};
    export const Profile = {};
    export const Profiles = {};
    export const ProfileSwitcher = {};
    export const Restrictions = {};
    export const Session = {};
    export const SetConfigParams = {};
    export const Settings = {};
    export const Status = {};
    export const UILog = {};
    export const Update = {};
    export const Version = {};
    export const WindowManager = {};
    MDLEOF

    cat > $bindingsDir/i18n/models.js << 'EOF'
    export const Language = {};
    export const LanguageCode = {};
    EOF

    cat > $bindingsDir/preferences/models.js << 'EOF'
    export const ViewMode = {};
    EOF

    cat > $bindingsDir/updater/models.js << 'EOF'
    export const State = {};
    EOF

    # --- Install dependencies & build frontend ---
    cd client/ui/frontend

    pnpm install --offline --ignore-scripts --frozen-lockfile
    pnpm vite build --mode production

    cd ../../..
  '';

  postInstall =
    let
      builtBinaryName = lib.last (lib.splitString "/" component.module);
    in
    ''
      mv $out/bin/${builtBinaryName} $out/bin/${component.binaryName}
    ''
    +
      lib.optionalString
        (stdenv.buildPlatform.canExecute stdenv.hostPlatform && (component.hasCompletion or false))
        ''
          installShellCompletion --cmd ${component.binaryName} \
            --bash <($out/bin/${component.binaryName} completion bash) \
            --fish <($out/bin/${component.binaryName} completion fish) \
            --zsh <($out/bin/${component.binaryName} completion zsh)
        ''
    + lib.optionalString (stdenv.hostPlatform.isLinux && componentName == "ui") ''
      install -Dm644 "$src/client/ui/assets/netbird.png" "$out/share/icons/hicolor/256x256/apps/netbird.png"
      install -Dm644 "$src/client/ui/build/linux/netbird-ui.desktop" "$out/share/applications/netbird.desktop"

    '';

  nativeInstallCheckInputs = lib.lists.optionals (component ? versionCheckProgramArg) [
    versionCheckHook
  ];
  versionCheckProgram = "${placeholder "out"}/bin/${component.binaryName}";
  versionCheckProgramArg = component.versionCheckProgramArg or "version";

  passthru = {
    tests = lib.attrsets.optionalAttrs (componentName == "client") {
      nixos = nixosTests.netbird;
      inherit
        netbird-management
        netbird-relay
        netbird-signal
        netbird-ui
        netbird-upload
        netbird-proxy
        ;
    };
    updateScript = nix-update-script { };
  };

  meta = {
    homepage = "https://netbird.io";
    changelog = "https://github.com/netbirdio/netbird/releases/tag/v${finalAttrs.version}";
    description = "Connect your devices into a single secure private WireGuard®-based mesh network with SSO/MFA and simple access controls";
    license = component.license;
    maintainers = with lib.maintainers; [
      nazarewk
      saturn745
      loc
    ];
    mainProgram = component.binaryName;
  };
})
